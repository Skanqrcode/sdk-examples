# skanqrcode

Dart client for the [SkanQRCode](https://skanqrcode.com) API (OpenAPI 1.7.0). See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full request/response contract.

## Install

```sh
dart pub add skanqrcode
```

## Usage

Keys look like `sk_test_<id>_<secret>` (free sandbox) or `sk_live_<id>_<secret>` (paid); the
prefix is set by your plan.

```dart
import 'dart:io';

import 'package:skanqrcode/skanqrcode.dart';

Future<void> main() async {
  final client = SkanQRCodeClient(apiKey: Platform.environment['SKANQRCODE_API_KEY']!);

  try {
    final result = await client.checkUrl('https://example.com/login', userId: 'user-4821');

    switch (result.action) {
      case Action.allow:
        print('Safe to open (${result.executionTimeMs} ms, ${result.environment.name}).');
      case Action.warn:
        print('Warn user: ${result.reasons.join(', ')}');
      case Action.block:
        print('Blocked: ${result.reasons.join(', ')}');
      case Action.unknown:
        print('Unrecognized action — treat like warn.');
    }
  } on SkanQRCodeException catch (e) {
    print('Check failed [${e.code}]: ${e.message} (requestId: ${e.requestId})');
    if (e.code == ErrorCode.rateLimited && e.retryAfter != null) {
      print('Try again in ${e.retryAfter}s.');
    }
  } finally {
    client.close();
  }
}
```

`CheckResult` fields: `verdict`, `action`, `mode`, `reasons` (plain strings), `finalUrl`,
`cached`, `executionTimeMs`, `environment` (`sandbox`/`production`), `licensedForProduction`,
`requestId`, and `related` (IP mode only). `score` and `partial` no longer exist: branch on
`action`. `userId` is
optional and only sent when provided. Sandbox results are for integration testing only.

`result.shouldBlock` is `action == Action.block` and `result.isSafe` is
`action == Action.allow`; `warn` is neither, so surface it to the user. Server enums (`Verdict`,
`Action`, `Mode`, `Environment`) decode unknown values as `.unknown` instead of throwing, and
`.unknown` is never "safe".

In a Flutter file, `Action` clashes with Flutter's own `Action` class — import
`package:flutter/material.dart` with `hide Action`.

### Usage

```dart
final monthly = await client.getUsage(month: '2026-09'); // month is optional (YYYY-MM, UTC)
print('${monthly.totalRequests}/${monthly.monthlyQuota}, ${monthly.availableRequests} left');

final hourly = await client.getUsageHourly(month: '2026-09');
for (final hour in hourly.hours.where((h) => h.capacityUsedPercent > 90)) {
  print('${hour.hour} ran at ${hour.capacityUsedPercent}% of the rate limit');
}
```

### Allow list and block list

The block list works on every plan; the allow list needs Pro or Business (otherwise
`plan_feature_unavailable`). Writes need an `admin`-scope key (otherwise `forbidden`).

```dart
final entry = await client.addBlockListEntry(
  matchType: MatchType.domain,
  value: 'malicious-example.com',
);

String? cursor;
do {
  final page = await client.listBlockList(limit: 100, cursor: cursor);
  for (final e in page.entries) {
    print('${e.id} ${e.matchType.name} ${e.value}');
  }
  cursor = page.nextCursor;
} while (cursor != null);

await client.deleteBlockListEntry(entry.id); // 204, no body
```

`MatchType` is `url`, `host`, `domain` or `ip`. Adding is idempotent (created and
already-existing both succeed). `listAllowList` / `addAllowListEntry` / `deleteAllowListEntry`
mirror the block-list calls.

### Billing (human-in-the-loop)

`createCheckoutSession(planId:, turnstileToken:)` and `createPortalSession()` return a
`SessionUrl` and need an `admin`-scope key. They exist so a person can start a subscription or
manage billing — hand the URL to a human, never complete checkout from an autonomous agent.
Checkout also needs a Turnstile token from a real browser flow.

### Health

`await client.getHealth()` returns `status: 'ok'` and needs no key. Liveness only.

## Errors

Every non-2xx response throws `SkanQRCodeException` with `code`, `message`, `requestId`,
`httpStatus` and `retryAfter` (seconds, from `Retry-After`; `null` if absent). Branch on `code`,
never on `message`. The documented codes are available as `ErrorCode.*`:

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

`code` is a plain string, so a code added later still surfaces. `e.isRetryable` is true for
`rate_limited`, `auth_unavailable` and 5xx; the SDK never retries on its own. Network failures
and timeouts (default 5s) propagate as `SocketException` / `TimeoutException` — treat them as
"couldn't verify" and fail closed.
