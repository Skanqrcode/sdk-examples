# SkanQRCode Swift quickstart

Raw `POST /v1/check` call using `URLSession` and Swift concurrency — no SDK, just the
standard library and Foundation. See [`../../sdk/swift`](../../sdk/swift) for an installable
package version, and [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full
API contract.

## Requirements

- Swift 5.9+ (macOS or Linux)
- A SkanQRCode API key

## Run

```sh
export SKANQRCODE_API_KEY=sk_test_...
swift main.swift                          # checks a built-in example URL
swift main.swift "https://example.com"    # or pass your own target
```

The script exits `0` for `allow`/`warn`, `2` for `block`, and `1` on request/API errors.
