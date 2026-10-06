# skanqrcode

Plain-JS client for the SkanQRCode API — CommonJS and ESM, no build step, no runtime
dependencies (uses global `fetch`). See
[../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.

## Install

```bash
npm install skanqrcode
```

## Usage

```js
const { SkanQRCodeClient, shouldBlock } = require("skanqrcode");
// or: import { SkanQRCodeClient, shouldBlock } from "skanqrcode";

// sk_test_... keys are sandbox; sk_live_... keys are production.
const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

const result = await client.checkUrl("https://example.com/login");

// Branch on `action`: allow / warn / block.
if (shouldBlock(result)) {
  console.log("Blocked:", result.reasons.join(", "));
} else if (result.action === "warn") {
  console.log("Proceed with caution:", result.reasons.join(", "));
} else {
  console.log("Safe to open.");
}

// Sandbox keys return environment "sandbox" / licensedForProduction false:
// integration-test output only, don't enforce on it in production.
console.log(result.environment, result.executionTimeMs, "ms");
```

`checkUrl(target, userId?)` takes an optional opaque end-user id that enables per-user result
caching. `shouldBlock(result)` is true only for `action === "block"` and `isSafe(result)` only
for `"allow"` — `warn` is neither, so surface it to the user.

## Usage and lists

```js
const { SkanQRCodeClient } = require("skanqrcode");

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

// Monthly summary (month is YYYY-MM, defaults to the current month) and hourly detail.
const usage = await client.getUsage("2026-09");
console.log(`${usage.totalRequests} / ${usage.monthlyQuota} (${usage.availableRequests} left)`);
const hourly = await client.getUsageHourly("2026-09");

// Block list (every plan) and allow list (Pro & Business). Writes need an admin-scope key.
const entry = await client.addBlockListEntry("domain", "malicious-example.com");

let cursor;
do {
  const page = await client.listBlockList(100, cursor);
  for (const e of page.entries) console.log(e.id, e.matchType, e.value);
  cursor = page.nextCursor ?? undefined;
} while (cursor);

await client.deleteBlockListEntry(entry.id);

// Billing helpers return a URL to hand to a person (admin scope, human-in-the-loop).
// const { url } = await client.createPortalSession();
```

The same methods exist for the allow list as `listAllowList`, `addAllowListEntry` and
`deleteAllowListEntry`. `getHealth()` needs no API key.

## Error handling

Non-2xx responses throw `SkanQRCodeError`, which carries the typed error fields from the API,
the HTTP `status`, and `retryAfter` (seconds, from `Retry-After` on 429s; otherwise `null`).
`code` is one of `invalid_request`, `unauthorized`, `forbidden`, `not_found`,
`plan_feature_unavailable`, `payment_required`, `rate_limited`, `quota_exceeded`,
`auth_unavailable`, `internal`. A non-JSON error body (e.g. a proxy's HTML 502) still throws
with code `internal` and the real status. The SDK doesn't retry on its own.

```js
const { SkanQRCodeClient, SkanQRCodeError } = require("skanqrcode");

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

try {
  await client.checkUrl("https://example.com");
} catch (err) {
  if (err instanceof SkanQRCodeError) {
    if (err.code === "rate_limited") {
      console.error(`Rate limited; retry in ${err.retryAfter ?? 1}s`);
    } else {
      console.error(err.status, err.code, err.message, err.requestId);
    }
  } else {
    throw err;
  }
}
```
