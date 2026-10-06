# SkanQRCode Swift SDK

Swift Package wrapping the [SkanQRCode API contract](../../docs/api-contract.md) (OpenAPI 1.7.0).

## Install

Add to `Package.swift` (illustrative URL — replace with the real package location once published):

```swift
.package(url: "https://github.com/skanqrcode/skanqrcode-swift", from: "1.0.0")
```

## Usage

Keys look like `sk_test_<id>_<secret>` (free sandbox) or `sk_live_<id>_<secret>` (paid); the
prefix is set by your plan.

```swift
import SkanQRCode

let client = SkanQRCodeClient(apiKey: ProcessInfo.processInfo.environment["SKANQRCODE_API_KEY"]!)

do {
    let result = try await client.checkURL("https://example.com/login", userId: "user-4821")
    switch result.action {
    case .allow: print("safe to open")
    case .warn: print("suspicious: \(result.reasons)")
    case .block: print("blocked: \(result.reasons)")
    case .unknown: print("unrecognized action — treat like warn")
    }
    print("\(result.verdict) in \(result.executionTimeMs) ms (\(result.environment), requestId: \(result.requestId))")
} catch let error as SkanQRCodeError {
    print("\(error.code): \(error.message) (requestId: \(error.requestId ?? "none"))")
    if error.code == SkanQRCodeError.Code.rateLimited, let wait = error.retryAfter {
        print("try again in \(wait)s")
    }
} catch {
    print("network error: \(error)")
}
```

`CheckResult` fields: `verdict`, `action`, `mode`, `reasons` (plain strings), `finalUrl`,
`cached`, `executionTimeMs`, `environment` (`sandbox`/`production`), `licensedForProduction`,
`requestId`, and `related` (IP mode only). `score` and `partial` no longer exist: branch on
`action`. `userId` is
optional and only sent when provided. Sandbox results are for integration testing only.

`result.shouldBlock` is `action == .block` and `result.isSafe` is `action == .allow`; `warn` is
neither, so surface it to the user. Server enums (`verdict`, `action`, `mode`, `environment`)
decode unknown values as `.unknown` instead of throwing, and `.unknown` is never "safe".

### Usage

```swift
let monthly = try await client.getUsage(month: "2026-09")   // month is optional (YYYY-MM, UTC)
print("\(monthly.totalRequests)/\(monthly.monthlyQuota), \(monthly.availableRequests) left")

let hourly = try await client.getUsageHourly(month: "2026-09")
for hour in hourly.hours where hour.capacityUsedPercent > 90 {
    print("\(hour.hour) ran at \(hour.capacityUsedPercent)% of the rate limit")
}
```

### Allow list and block list

The block list works on every plan; the allow list needs Pro or Business (otherwise
`plan_feature_unavailable`). Writes need an `admin`-scope key (otherwise `forbidden`).

```swift
let entry = try await client.addBlockListEntry(matchType: .domain, value: "malicious-example.com")

var cursor: String?
repeat {
    let page = try await client.listBlockList(limit: 100, cursor: cursor)
    page.entries.forEach { print($0.id, $0.matchType, $0.value) }
    cursor = page.nextCursor
} while cursor != nil

try await client.deleteBlockListEntry(entry.id)   // 204, no body
```

`matchType` is `.url`, `.host`, `.domain` or `.ip`. Adding is idempotent (created and
already-existing both succeed). `listAllowList` / `addAllowListEntry` / `deleteAllowListEntry`
mirror the block-list calls.

### Billing (human-in-the-loop)

`createCheckoutSession(planId:turnstileToken:)` and `createPortalSession()` return a URL
(`SessionURL.url`) and need an `admin`-scope key. They exist so a person can start a
subscription or manage billing — hand the URL to a human, never complete checkout from an
autonomous agent. Checkout also needs a Turnstile token from a real browser flow.

### Health

`try await client.getHealth()` returns `{status: "ok"}` and needs no key. Liveness only.

## Errors

Every non-2xx response throws `SkanQRCodeError` with `code`, `message`, `requestId`,
`httpStatus` and `retryAfter` (seconds, from `Retry-After`; `nil` if absent). Branch on `code`,
never on `message`. The documented codes are available as `SkanQRCodeError.Code.*`:

| Code | Meaning | Retry? |
|---|---|---|
| `invalid_request` (400) | Malformed request or unparseable target | No |
| `unauthorized` (401) | Key missing, malformed, unknown or revoked | No |
| `payment_required` (402) | Tenant suspended for non-payment | No |
| `forbidden` (403) | Key lacks the required scope (e.g. `admin`) | No |
| `plan_feature_unavailable` (403) | Plan doesn't include this feature | No |
| `not_found` (404) | Resource doesn't exist for this tenant | No |
| `rate_limited` (429) | Per-minute limit exceeded | After `retryAfter` |
| `quota_exceeded` (429) | Monthly quota exhausted | No |
| `auth_unavailable` (503) | Auth backend briefly unavailable | Shortly |
| `internal` (500) | Unexpected failure (also used for a non-JSON error body, e.g. a proxy's HTML 502) | With backoff |

`code` is a plain string, so a code added later still surfaces. `error.isRetryable` is true for
`rate_limited`, `auth_unavailable` and 5xx; the SDK never retries on its own. Network failures
and timeouts (default 5s) surface as `URLError` — treat them as "couldn't verify" and fail
closed.

See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full request/response
contract.
