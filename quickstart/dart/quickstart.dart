// Minimal, dependency-light example of calling POST /v1/check directly with
// package:http. For a full-featured client with typed models and error
// handling, see ../../sdk/dart instead.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _baseUrl = 'https://api.skanqrcode.com';

Future<void> main() async {
  final apiKey = Platform.environment['SKANQRCODE_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln('Set SKANQRCODE_API_KEY before running this example.');
    exit(1);
  }

  final target = 'https://example.com/login';

  final response = await http
      .post(
        Uri.parse('$_baseUrl/v1/check'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'target': target}),
      )
      .timeout(const Duration(seconds: 5));

  // A proxy's HTML 502 isn't the documented JSON, so only decode what we need.
  Map<String, dynamic>? body;
  try {
    body = jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {}

  if (response.statusCode != 200 || body == null) {
    final error = body?['error'] as Map<String, dynamic>?;
    final code = error?['code'] ?? 'internal';
    stderr.writeln(
      'Check failed [${response.statusCode} $code]: '
      '${error?['message'] ?? 'unexpected response'} '
      '(requestId: ${error?['requestId'] ?? 'none'})',
    );
    switch (code) {
      case 'rate_limited':
        stderr.writeln('Retry in ${response.headers['retry-after']}s.');
      case 'unauthorized' || 'payment_required' || 'quota_exceeded':
        stderr.writeln('Not retryable: check your API key, billing status or monthly quota.');
      case 'auth_unavailable' || 'internal':
        stderr.writeln('Retryable: try again shortly, with backoff.');
    }
    exit(1);
  }

  final action = body['action'] as String;
  final reasons = (body['reasons'] as List).cast<String>();

  print('target:    $target');
  print('verdict:   ${body['verdict']}');
  print('action:    $action');
  print('reasons:   ${reasons.join(', ')}');
  print('cached:    ${body['cached']}');
  print('time:      ${body['executionTimeMs']} ms');
  print('env:       ${body['environment']}');
  print('requestId: ${body['requestId']}');

  switch (action) {
    case 'block':
      print('\n=> Block: do not open this link.');
    case 'warn':
      print('\n=> Warn: confirm with the user before opening.');
    case 'allow':
      print('\n=> Allow: safe to open.');
    default:
      print('\n=> Unrecognized action: treat like warn.');
  }
}
