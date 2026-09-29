# SkanQRCode Swift SDK

Swift Package wrapping the [SkanQRCode API contract](../../docs/api-contract.md).

## Install

Add to `Package.swift` (illustrative URL — replace with the real package location once published):

```swift
.package(url: "https://github.com/skanqrcode/skanqrcode-swift", from: "1.0.0")
```

## Usage

```swift
import SkanQRCode

let client = SkanQRCodeClient(apiKey: ProcessInfo.processInfo.environment["SKANQRCODE_API_KEY"]!)

do {
    let result = try await client.checkURL("https://example.com/login")
    switch result.recommendation {
    case .proceed: print("safe to open")
    case .warn: print("suspicious: \(result.reasons)")
    case .block: print("blocked: \(result.reasons)")
    }
} catch let error as SkanQRCodeError {
    print("\(error.code): \(error.message) (requestId: \(error.requestId))")
} catch {
    print("network error: \(error)")
}
```

See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full request/response
contract and error codes.
