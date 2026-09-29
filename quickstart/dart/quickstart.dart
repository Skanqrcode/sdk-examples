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

  final body = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode != 200) {
    final error = body['error'] as Map<String, dynamic>;
    stderr.writeln(
      'Check failed [${error['code']}]: ${error['message']} '
      '(requestId: ${error['requestId']})',
    );
    exit(1);
  }

  final verdict = body['verdict'] as String;
  final score = body['score'] as int;
  final reasons = (body['reasons'] as List).cast<String>();

  print('target:    $target');
  print('verdict:   $verdict');
  print('score:     $score');
  print('reasons:   ${reasons.join(', ')}');
  print('cached:    ${body['cached']}');
  print('partial:   ${body['partial']}');
  print('requestId: ${body['requestId']}');

  if (verdict == 'malicious') {
    print('\n=> Block: do not open this link.');
  } else if (verdict == 'suspicious') {
    print('\n=> Warn: confirm with the user before opening.');
  } else {
    print('\n=> Proceed: safe to open.');
  }
}
