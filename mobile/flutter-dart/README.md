# SkanQRCode Flutter scanner example

Scans a QR code with [`mobile_scanner`](https://pub.dev/packages/mobile_scanner), checks the
decoded URL with the SkanQRCode SDK (see [`../../sdk/dart`](../../sdk/dart)), then launches it
with [`url_launcher`](https://pub.dev/packages/url_launcher) — or asks/blocks first, depending on
the verdict. See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the API contract.

Drop `scanner_screen.dart` into an existing Flutter app's `lib/` and push `ScannerScreen()`.

## Setup

Add to `pubspec.yaml`:

```yaml
dependencies:
  mobile_scanner: ^5.0.0
  url_launcher: ^6.3.0
  skanqrcode:
    path: ../sdk-examples/sdk/dart # or: skanqrcode: ^0.2.0, once published
```

Camera permissions: follow `mobile_scanner`'s [installation guide](https://pub.dev/packages/mobile_scanner#installation)
for the `NSCameraUsageDescription` (iOS) and `<uses-permission android:name="android.permission.CAMERA">` (Android) entries.

Run with the API key baked in at build time:

```sh
flutter run --dart-define=SKANQRCODE_API_KEY=sk_live_...
```

## Behavior

The screen branches on the server's `action`:

- **allow** (`not_malicious`) — opens the link immediately.
- **warn** (`suspicious`) — shows the matched reason codes with "Open anyway" / "Cancel".
- **block** (`malicious`) — shows the reason codes with no way to proceed.
- An error, a network failure or a timeout is treated as a block (fail closed) — see the
  comment in `scanner_screen.dart` for the reasoning. Error codes map to a message:
  `rate_limited` says to try again in N seconds (from `Retry-After`); `quota_exceeded`,
  `payment_required`, `unauthorized` and `forbidden` are reported as a configuration problem
  (rescanning won't help); anything else, including an unrecognized `action`, gets a generic
  "couldn't verify" message.

`scanner_screen.dart` imports Flutter with `hide Action` because the SDK's `Action` enum
clashes with Flutter's `Action` class.

An `sk_test_` key is sandbox-only: results carry `environment == Environment.sandbox` and
`licensedForProduction == false` and are for integration testing, not production enforcement.
