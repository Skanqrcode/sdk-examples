# skanqrcode-sdk (Java)

A typed, blocking Java client for the SkanQRCode API (OpenAPI v1.7.0). See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full HTTP contract this
wraps.

> **2.0.0 is a breaking release.** `CheckResult` drops `score` and `partial` and gains the
> server-provided `action`; `Recommendation` is gone; `getUsage(from, to)` is now
> `getUsage(month)` and the hourly buckets moved to `getUsageHourly(month)`; error codes changed.

## Install

```xml
<dependency>
  <groupId>com.skanqrcode</groupId>
  <artifactId>skanqrcode-sdk</artifactId>
  <version>2.0.0</version>
</dependency>
```

## Usage

```java
import com.skanqrcode.sdk.Action;
import com.skanqrcode.sdk.CheckResult;
import com.skanqrcode.sdk.SkanQRCodeClient;
import com.skanqrcode.sdk.SkanQRCodeException;

public class Example {
    public static void main(String[] args) throws Exception {
        // Keys are sk_test_... (sandbox) or sk_live_... (production).
        SkanQRCodeClient client = new SkanQRCodeClient(System.getenv("SKANQRCODE_API_KEY"));

        try {
            // The optional second argument is an opaque end-user id that enables per-user caching.
            CheckResult result = client.checkUrl("https://example.com/login", "user-4821");
            switch (result.getAction()) {
                case ALLOW -> System.out.println("safe to open");
                case WARN -> System.out.println("warn: " + result.getReasons());
                case BLOCK -> System.out.println("blocked: " + result.getReasons());
            }
            System.out.println(result.getEnvironment() + " in " + result.getExecutionTimeMs() + "ms, requestId=" + result.getRequestId());
        } catch (SkanQRCodeException e) {
            System.out.println(e.getCode() + ": " + e.getMessage() + " (requestId=" + e.getRequestId() + ")");
        }
    }
}
```

`CheckResult` fields: `verdict`, `action` (`Action.ALLOW` / `WARN` / `BLOCK`), `mode`, `reasons`
(plain strings, so a new reason code won't break parsing), `finalUrl` (nullable), `cached`,
`executionTimeMs`, `environment`, `licensedForProduction`, `requestId`, and `related` (IP mode
only; empty otherwise). `action` is what to branch on; `shouldBlock()` (`action == BLOCK`) and
`isSafe()` (`action == ALLOW`) are shortcuts. `WARN` is neither — surface it to the user.

- `executionTimeMs >= 180` means the evaluation deadline was hit and the result is best-effort.
- `environment == "sandbox"` / `licensedForProduction == false` (`sk_test_` keys) is
  integration-test output only — don't enforce on it in production.

## Usage aggregates

```java
// Monthly summary. Pass "YYYY-MM" (UTC), or call getUsage() for the current month.
UsageResponse usage = client.getUsage("2026-09");
System.out.println(usage.getTotalRequests() + " of " + usage.getMonthlyQuota() + " used, "
        + usage.getAvailableRequests() + " left");

// Hour by hour, with per-minute rate-limit utilization.
HourlyUsageResponse hourly = client.getUsageHourly("2026-09");
for (UsageHour hour : hourly.getHours()) {
    System.out.println(hour.getHour() + " " + hour.getMode() + ": " + hour.getTotal() + " checks, "
            + hour.getCapacityUsedPercent() + "% of capacity");
}
```

Figures come from billing aggregates and can lag real time by up to about an hour.

## Allow list and block list

The block list works on every plan; the allow list needs Pro or Business. Writes need a key
with the `admin` scope.

```java
ListEntriesResponse page = client.listBlockList(100, null);      // limit, cursor (both nullable)
while (true) {
    for (ListEntry entry : page.getEntries()) {
        System.out.println(entry.getId() + " " + entry.getMatchType() + " " + entry.getValue());
    }
    if (page.getNextCursor() == null) break;
    page = client.listBlockList(100, page.getNextCursor());
}

ListEntry added = client.addBlockListEntry(MatchType.DOMAIN, "malicious-example.com"); // idempotent
client.deleteBlockListEntry(added.getId());                                            // 204, returns void
```

`listAllowList` / `addAllowListEntry` / `deleteAllowListEntry` have the same shape.

## Billing and health

`createCheckoutSession(planId, turnstileToken)` and `createPortalSession()` return a URL
(`getUrl()`). They need an `admin`-scope key and are **human-in-the-loop**: hand the URL to a
person, never complete checkout from an autonomous agent. `getHealth()` needs no API key.

## Error handling

Every non-2xx response throws `SkanQRCodeException` with `getCode()`, `getMessage()`,
`getRequestId()`, `getHttpStatus()` and `getRetryAfter()` (seconds from the `Retry-After`
header, or `null`). Branch on the code, never the message:

```java
try {
    client.checkUrl(target);
} catch (SkanQRCodeException e) {
    switch (e.getCode()) {
        case ErrorCode.RATE_LIMITED -> Thread.sleep(e.getRetryAfter() != null ? e.getRetryAfter() * 1000L : 1000L); // then retry
        case ErrorCode.QUOTA_EXCEEDED, ErrorCode.PAYMENT_REQUIRED, ErrorCode.UNAUTHORIZED -> { /* configuration problem; don't retry */ }
        default -> { /* log e.getRequestId() for support */ }
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
(`new SkanQRCodeClient(apiKey, baseUrl, timeoutMs)` to change it), so in UI code treat a timeout
as "don't open".
