// The SDK's `Action` enum clashes with Flutter's `Action` class.
import 'package:flutter/material.dart' hide Action;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skanqrcode/skanqrcode.dart';
import 'package:url_launcher/url_launcher.dart';

// Mobile apps don't have a shell environment, so the key is baked in at
// build time: flutter run --dart-define=SKANQRCODE_API_KEY=sk_live_...
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
      // Fail closed on every API error: the link is never opened.
      await _showBlockingDialog(
        title: 'Couldn\'t check this link',
        body: _messageFor(e),
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

  /// Maps an API error to user-facing text. Nothing here ever opens the link.
  String _messageFor(SkanQRCodeException e) {
    final requestId = 'Request ID: ${e.requestId ?? 'none'}';
    switch (e.code) {
      case ErrorCode.rateLimited:
        final wait = e.retryAfter == null ? 'in a moment' : 'in ${e.retryAfter} seconds';
        return 'Too many scans right now. Try again $wait.';
      case ErrorCode.quotaExceeded ||
            ErrorCode.paymentRequired ||
            ErrorCode.unauthorized ||
            ErrorCode.forbidden:
        // Not something the user can fix by rescanning: an API key, plan or
        // quota problem.
        return 'Link checking isn\'t available because of a configuration '
            'problem. Contact the app\'s developer.\n\n${e.code}\n$requestId';
      default:
        // invalid_request, auth_unavailable, internal, unknown codes, non-JSON
        // proxy errors…
        return 'We couldn\'t verify this link is safe, so it wasn\'t opened. '
            'Please try scanning again.\n\n$requestId';
    }
  }

  Future<void> _handleResult(String target, CheckResult result) async {
    switch (result.action) {
      case Action.allow:
        await launchUrl(Uri.parse(target));
      case Action.warn:
        final proceed = await _showConfirmDialog(
          title: 'This link looks suspicious',
          reasons: result.reasons,
        );
        if (proceed) await launchUrl(Uri.parse(target));
      case Action.block:
        await _showBlockingDialog(
          title: 'This link is unsafe',
          body: 'SkanQRCode blocked this link:\n\n${result.reasons.join('\n')}',
        );
      case Action.unknown:
        // An action this SDK version doesn't know: fail closed.
        await _showBlockingDialog(
          title: 'Couldn\'t check this link',
          body: 'We couldn\'t verify this link is safe, so it wasn\'t opened.',
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
