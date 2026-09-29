# skanqrcode

Dart client for the [SkanQRCode](https://skanqrcode.com) API. See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full request/response contract.

## Install

```sh
dart pub add skanqrcode
```

## Usage

```dart
import 'dart:io';

import 'package:skanqrcode/skanqrcode.dart';

Future<void> main() async {
  final client = SkanQRCodeClient(apiKey: Platform.environment['SKANQRCODE_API_KEY']!);

  try {
    final result = await client.checkUrl('https://example.com/login');

    switch (result.recommendation) {
      case Recommendation.proceed:
        print('Safe to open (score ${result.score}).');
      case Recommendation.warn:
        print('Warn user: ${result.reasons.join(', ')}');
      case Recommendation.block:
        print('Blocked: ${result.reasons.join(', ')}');
    }
  } on SkanQRCodeException catch (e) {
    print('Check failed [${e.code}]: ${e.message} (requestId: ${e.requestId})');
  } finally {
    client.close();
  }
}
```
