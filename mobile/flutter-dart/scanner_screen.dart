import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skanqrcode/skanqrcode.dart';
import 'package:url_launcher/url_launcher.dart';

// Mobile apps don't have a shell environment, so the key is baked in at
// build time: flutter run --dart-define=SKANQRCODE_API_KEY=lure_live_...
const _apiKey = String.fromEnvironment('SKANQRCODE_API_KEY');

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _client = SkanQRCodeClient(apiKey: _apiKey);

  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_checking) return;

    if (capture.barcodes.isEmpty) return;
    final target = capture.barcodes.first.rawValue;
    if (target == null) return;

    setState(() => _checking = true);
    await _controller.stop();

    try {
      final result = await _client.checkUrl(target);
      await _handleResult(target, result);
    } on SkanQRCodeException catch (e) {
      await _showBlockingDialog(
        title: 'Couldn\'t check this link',
        body: '${e.message}\n\nRequest ID: ${e.requestId}',
      );
    } catch (_) {
      // Network failure or timeout: no verdict, so fail closed rather than
      // silently letting the QR payload through unchecked.
      await _showBlockingDialog(
        title: 'Couldn\'t check this link',
        body: 'The safety check timed out or failed. For your protection, '
            'this link was not opened.',
      );
    }

    if (!mounted) return;
    setState(() => _checking = false);
    await _controller.start();
  }

  Future<void> _handleResult(String target, CheckResult result) async {
    switch (result.recommendation) {
      case Recommendation.proceed:
        await launchUrl(Uri.parse(target));
      case Recommendation.warn:
        final proceed = await _showConfirmDialog(
          title: 'This link looks suspicious',
          reasons: result.reasons,
        );
        if (proceed) await launchUrl(Uri.parse(target));
      case Recommendation.block:
        await _showBlockingDialog(
          title: 'This link is unsafe',
          body: 'SkanQRCode blocked this link:\n\n${result.reasons.join('\n')}',
        );
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required List<String> reasons,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(reasons.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showBlockingDialog({
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a QR code')),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          if (_checking)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Checking link safety…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
