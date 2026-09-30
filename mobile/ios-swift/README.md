# SkanQRCode iOS scanner example

A SwiftUI screen that scans a QR code with `AVFoundation`, checks the decoded URL against
SkanQRCode before opening it, and branches the UI on the server's `action`:

- **allow** — opens the URL immediately with `UIApplication.shared.open(_:)`.
- **warn** — shows a confirmation alert with the reason codes before opening.
- **block** — shows a blocking alert with the reason codes and no way to proceed.
- **error / timeout** — fails closed: the link is never auto-opened, and the user has to
  rescan. Error codes are mapped to a message: `rate_limited` says to try again in N seconds
  (from `Retry-After`); `quota_exceeded`, `payment_required`, `unauthorized` and `forbidden`
  are reported as a configuration problem (rescanning won't help); anything else, including an
  unrecognized `action`, gets a generic "couldn't verify" message. See the comments in
  `ScannerView.swift` for the tradeoff.

## Requirements

- iOS 15+ (uses the `.alert(_:isPresented:presenting:actions:message:)` SwiftUI API)
- `NSCameraUsageDescription` in your app's `Info.plist`
- The [`SkanQRCode` package](../../sdk/swift) added as a dependency
- `SKANQRCODE_API_KEY` available to the process (e.g. via an Xcode scheme environment
  variable during development — don't ship a raw API key in a client app; proxy the call
  through your backend for production). An `sk_test_` key is sandbox-only: results come back
  with `environment == .sandbox` / `licensedForProduction == false` and are for integration
  testing, not production enforcement.

## Usage

Drop `ScannerView.swift` into your app and present it, e.g. `ScannerView()` from a sheet or
a navigation destination. See [`../../docs/api-contract.md`](../../docs/api-contract.md) for
the underlying API contract.
