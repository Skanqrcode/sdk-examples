# skanqrcode-sdk (Kotlin)

A typed Kotlin client for the SkanQRCode API (OpenAPI v1.7.0). See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full HTTP contract this
wraps.

> **2.0.0 is a breaking release.** `CheckResult` drops `score` and `partial` and gains the
> server-provided `action`; `Recommendation` is gone; `getUsage(from, to)` is now
> `getUsage(month)` and the hourly buckets moved to `getUsageHourly(month)`; error codes changed.

## Install

```kotlin
dependencies {
    implementation("com.skanqrcode:skanqrcode-sdk:2.0.0")
}
```

## Usage

```kotlin
import com.skanqrcode.sdk.Action
import com.skanqrcode.sdk.SkanQRCodeClient
import com.skanqrcode.sdk.SkanQRCodeException

suspend fun main() {
    // Keys are sk_test_... (sandbox) or sk_live_... (production).
    val client = SkanQRCodeClient(apiKey = System.getenv("SKANQRCODE_API_KEY"))

    try {
        // userId is optional: an opaque end-user id that enables per-user caching.
        val result = client.checkUrl("https://example.com/login", userId = "user-4821")
        when (result.action) {
            Action.ALLOW -> println("safe to open")
            Action.WARN -> println("warn: ${result.reasons}")
            Action.BLOCK -> println("blocked: ${result.reasons}")
        }
        println("${result.environment} in ${result.executionTimeMs}ms, requestId=${result.requestId}")
    } catch (e: SkanQRCodeException) {
        println("${e.code}: ${e.message} (requestId=${e.requestId})")
    }
}
```

`CheckResult` fields: `verdict`, `action` (`Action.ALLOW` / `WARN` / `BLOCK`), `mode`, `reasons`
(plain strings, so a new reason code won't break parsing), `finalUrl` (nullable), `cached`,
`executionTimeMs`, `environment`, `licensedForProduction`, `requestId`, and `related` (IP mode
only; empty otherwise). `action` is what to branch on; `shouldBlock` (`action == BLOCK`) and
`isSafe` (`action == ALLOW`) are shortcuts. `WARN` is neither — surface it to the user.

- `executionTimeMs >= 180` means the evaluation deadline was hit and the result is best-effort.
- `environment == SANDBOX` / `licensedForProduction == false` (`sk_test_` keys) is
  integration-test output only — don't enforce on it in production.

## Usage aggregates

```kotlin
// Monthly summary. Pass "YYYY-MM" (UTC), or omit it for the current month.
val usage = client.getUsage("2026-09")
println("${usage.totalRequests} of ${usage.monthlyQuota} used, ${usage.availableRequests} left")

// Hour by hour, with per-minute rate-limit utilization.
val hourly = client.getUsageHourly("2026-09")
for (hour in hourly.hours) {
    println("${hour.hour} ${hour.mode}: ${hour.total} checks, ${hour.capacityUsedPercent}% of capacity")
}
```

Figures come from billing aggregates and can lag real time by up to about an hour.

## Allow list and block list

The block list works on every plan; the allow list needs Pro or Business. Writes need a key
with the `admin` scope.

```kotlin
var page = client.listBlockList(limit = 100)
while (true) {
    page.entries.forEach { println("${it.id} ${it.matchType} ${it.value}") }
    val next = page.nextCursor ?: break
    page = client.listBlockList(limit = 100, cursor = next)
}

val added = client.addBlockListEntry(MatchType.DOMAIN, "malicious-example.com") // idempotent
client.deleteBlockListEntry(added.id)                                          // 204, returns Unit
```

`listAllowList` / `addAllowListEntry` / `deleteAllowListEntry` have the same shape.

## Billing and health

`createCheckoutSession(planId, turnstileToken)` and `createPortalSession()` return a
`SessionUrlResponse` (`url`). They need an `admin`-scope key and are **human-in-the-loop**:
hand the URL to a person, never complete checkout from an autonomous agent. `getHealth()` needs
no API key.

## Error handling

Every non-2xx response throws `SkanQRCodeException` with `code`, `message`, `requestId`,
`httpStatus` and `retryAfter` (seconds from the `Retry-After` header, or `null`). Branch on the
code, never the message:

```kotlin
try {
    client.checkUrl(target)
} catch (e: SkanQRCodeException) {
    when (e.code) {
        ErrorCode.RATE_LIMITED -> delay((e.retryAfter ?: 1) * 1000L) // then retry
        ErrorCode.QUOTA_EXCEEDED, ErrorCode.PAYMENT_REQUIRED, ErrorCode.UNAUTHORIZED -> Unit // configuration problem; don't retry
        else -> println("failed, requestId=${e.requestId}")
    }
}
```

Codes (constants on `ErrorCode`): `invalid_request`, `unauthorized`, `forbidden`,
`not_found`, `plan_feature_unavailable`, `payment_required`, `rate_limited`, `quota_exceeded`,
`auth_unavailable`, `internal`. The code is a plain string, so a code added later won't break
the client. If a proxy returns a non-JSON body (an HTML 502, say) you still get a
`SkanQRCodeException` with code `internal` and the HTTP status.

The SDK never retries on its own: don't retry `invalid_request`, `unauthorized`,
`payment_required`, `forbidden`, `not_found` or `quota_exceeded`; retry `rate_limited` after
`Retry-After`, `auth_unavailable` shortly, and 5xx with backoff. The default timeout is 5 seconds
(`SkanQRCodeClient(apiKey, baseUrl, timeoutMs)` to change it), so in UI code treat a timeout as
"don't open".
