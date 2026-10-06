# SkanQRCode API — contract used by these examples

This is the request/response shape every example and SDK package in this repo codes against.
It mirrors the published OpenAPI 3.1 document (**version 1.7.0**):

```
https://docs.skanqrcode.com/openapi.json      (also served at https://api.skanqrcode.com/openapi.json)
```

When the spec changes, update this file first, then the SDKs. Every SDK and example links back
here instead of repeating the field tables.

## Base URL

```
https://api.skanqrcode.com
```

This is the only API host — there is no staging host. Sandbox access is an `sk_test_` key on
the same host.

## Authentication

Every operation except `GET /health`, `GET /openapi.json` and the billing webhook requires an
API key:

```
Authorization: Bearer <API_KEY>
```

- Paid tenants get an `sk_live_<id>_<secret>` key; free (sandbox) tenants get an
  `sk_test_<id>_<secret>` key only. The prefix is set by the plan, not chosen by the caller.
- Keys are shown once, at tenant creation.
- Never send the key as a query parameter — it isn't supported and would leak into logs/proxies.
- Some operations additionally need a key with the **`admin` scope** (list writes, billing);
  a key without it gets `403 forbidden`.

All examples read the key from an environment variable, `SKANQRCODE_API_KEY`, rather than
hardcoding it.

## Operations

| Operation | Method & path | Auth | Notes |
|---|---|---|---|
| `checkUrl` | `POST /v1/check` | key | The hot path. Consumes one quota unit. |
| `getUsage` | `GET /v1/usage?month=YYYY-MM` | key | Monthly quota summary. |
| `getUsageHourly` | `GET /v1/usage/hourly?month=YYYY-MM` | key | Hour-by-hour usage + rate-limit utilization. |
| `listAllowList` | `GET /v1/allow-list?limit&cursor` | key | Pro & Business plans only. |
| `addAllowListEntry` | `POST /v1/allow-list` | key + `admin` | Pro & Business plans only. `201` created / `200` already existed. |
| `deleteAllowListEntry` | `DELETE /v1/allow-list/{entryId}` | key + `admin` | Pro & Business plans only. `204`. |
| `listBlockList` | `GET /v1/block-list?limit&cursor` | key | Every plan. |
| `addBlockListEntry` | `POST /v1/block-list` | key + `admin` | Every plan. `201` / `200`. |
| `deleteBlockListEntry` | `DELETE /v1/block-list/{entryId}` | key + `admin` | Every plan. `204`. |
| `createCheckoutSession` | `POST /v1/billing/checkout` | key + `admin` | Human-in-the-loop — hand the URL to a person. |
| `createPortalSession` | `POST /v1/billing/portal` | key + `admin` | Human-in-the-loop — hand the URL to a person. |
| `getHealth` | `GET /health` | none | Liveness only. |
| `getOpenApiSpec` | `GET /openapi.json` | none | The spec itself. |
| `handleStripeWebhook` | `POST /v1/billing/webhook` | `Stripe-Signature` | **Not for API clients** — not in any SDK. |

## `POST /v1/check`

Classifies one URL or IP address and recommends what to do about it. Call it before letting a
user follow a link, open a QR-code destination, or accept a connection from an IP you don't
already trust.

- **Consumes one unit of the tenant's monthly quota per successful call, including cache
  hits.** Unparseable input (400) and blocked requests (429) are not billed.
- Quota and the per-minute limit are counted **per tenant** across all keys and IPs.
- The evaluation always returns a verdict.
- Sandbox (`sk_test_`) keys return `environment: "sandbox"` and `licensedForProduction: false`.
  Use those results for integration testing only — don't enforce on them in production.

### Request

```json
{ "target": "https://example.com/login", "userId": "user-4821" }
```

| Field | Type | Notes |
|---|---|---|
| `target` | string, required, 1–4096 chars | A URL or IPv4/IPv6 address. Decimal, hex and octal IPv4 forms are treated as IPs. |
| `userId` | string, optional, 1–128 chars | Opaque end-user identifier. Enables per-user result caching. Hashed before use; never stored or logged in clear. |

Request bodies over 8 KB are rejected with 400.

### Response — `200 OK`

```json
{
  "verdict": "malicious",
  "action": "block",
  "mode": "url",
  "reasons": ["ACTIVE_THREAT_FEED_MATCH", "KNOWN_MALWARE_MATCH"],
  "finalUrl": null,
  "cached": false,
  "executionTimeMs": 38,
  "environment": "production",
  "licensedForProduction": true,
  "requestId": "req_01j9z8qaenp0s2c4d6f8g0h1jk"
}
```

| Field | Type | Notes |
|---|---|---|
| `verdict` | `"not_malicious" \| "suspicious" \| "malicious"` | The classification. |
| `action` | `"allow" \| "warn" \| "block"` | What the caller should do. Fixed mapping on every plan: `not_malicious`→`allow`, `suspicious`→`warn`, `malicious`→`block`. Branch on this. |
| `mode` | `"url" \| "ip"` | How the target was evaluated. |
| `reasons` | string[] | Reason codes that contributed — see [Reason codes](#reason-codes). |
| `finalUrl` | string \| null | Where a shortened link resolved to, if a redirect was followed. |
| `cached` | boolean | True only if served from this tenant's own per-user cache. |
| `executionTimeMs` | integer ≥ 0 | Server-side evaluation time in milliseconds. |
| `environment` | `"sandbox" \| "production"` | Derived from the key's plan, never from the request. |
| `licensedForProduction` | boolean | `false` on the free sandbox plan. Never changes `verdict`/`action`. |
| `requestId` | string | Quote this to support. |
| `related` | `{host, verdict}[]`, optional, ≤ 20 | **IP mode only**: recently associated hosts, most recent first. |

Response headers worth reading: `X-Request-Id`, `Server-Timing`, `RateLimit-Limit`.

### Reason codes

The `reasons` array is a closed set of codes that name a *category* of evidence, never a data
source. SDKs keep them as plain strings (so a new code doesn't break deserialization) and
document the current set:

```
BRAND_LOOKALIKE_DOMAIN  BRAND_IMPERSONATION  DECEPTIVE_URL_USERINFO  BRAND_NAME_IN_DOMAIN
IP_ADDRESS_HOST  MIXED_SCRIPT_DOMAIN  HOSTED_ON_MALICIOUS_IP  NEWLY_REGISTERED_DOMAIN
HOSTED_FORM_ON_SHARED_PLATFORM  MALICIOUS_IP_ASSOCIATION  MALICIOUS_HOSTING_NEIGHBORHOOD
FILE_SHARING_HOST  SUSPICIOUS_CONTENT_OWNER  EXECUTABLE_PAYLOAD  HIGH_RISK_TLD
RANDOMIZED_DOMAIN_NAME  EXCESSIVE_SUBDOMAINS  CREDENTIAL_LURE_KEYWORDS  CLOUD_HOSTED_IP
INSECURE_CREDENTIAL_PAGE  URL_SHORTENER_REDIRECT  POPULAR_DOMAIN  ACTIVE_THREAT_FEED_MATCH
KNOWN_MALWARE_MATCH  KNOWN_PHISHING_MATCH  UNWANTED_SOFTWARE_MATCH  THREAT_INTEL_UNCONFIRMED
SUSPICIOUS_IP_ASSOCIATION  SHARED_INFRASTRUCTURE_IP  NON_PUBLIC_IP  NO_THREAT_INTEL
UNRESOLVED_REDIRECT  UNSUPPORTED_SCHEME  BLOCK_LIST_MATCH  ALLOW_LIST_CONFLICT
ALLOW_LIST_MATCH  ADMINISTRATIVE_OVERRIDE  EVALUATION_ERROR
```

## `GET /v1/usage?month=YYYY-MM`

Monthly usage summary. `month` is a UTC calendar month and defaults to the current one. Figures
come from billing aggregates and can lag real time by up to about an hour — use this for
reporting, not for deciding whether the next call will succeed.

```json
{
  "tenantId": "ten_01j9z2k3f5g6h7a1b2c3d4e5f6",
  "month": "2026-09",
  "monthlyQuota": 50000,
  "totalRequests": 42817,
  "availableRequests": 7183
}
```

`availableRequests = max(monthlyQuota - totalRequests, 0)`. On plans that bill overage, zero
means the next request is billed as overage rather than blocked.

> **Breaking change from earlier drafts:** `/v1/usage` no longer takes `from`/`to` and no
> longer returns hourly buckets. Hourly data moved to `/v1/usage/hourly`.

## `GET /v1/usage/hourly?month=YYYY-MM`

Hour-by-hour usage for one month, with per-minute rate-limit utilization.

```json
{
  "tenantId": "ten_01j9z2k3f5g6h7a1b2c3d4e5f6",
  "month": "2026-09",
  "rpmLimit": 30,
  "hourlyCapacity": 1800,
  "hours": [
    {
      "hour": "2026-09-01T09:00:00Z",
      "mode": "url",
      "total": 1766,
      "capacityUsedPercent": 98.1,
      "blockedRpm": 34,
      "blockedQuota": 0,
      "malicious": 5,
      "suspicious": 40,
      "notMalicious": 1721,
      "cached": 1200
    }
  ]
}
```

| Field | Notes |
|---|---|
| `rpmLimit` | The plan's requests-per-minute limit. |
| `hourlyCapacity` | `rpmLimit * 60`. A reading aid only — limits are enforced per minute, there is no hourly quota. |
| `hours[].capacityUsedPercent` | `total / hourlyCapacity * 100`, one decimal (number, not integer). Near 100 ⇒ that hour ran at the rate limit. |
| `hours[].blockedRpm` / `blockedQuota` | Requests blocked that hour for exceeding the per-minute limit / the monthly quota. |
| `hours[].malicious` / `suspicious` / `notMalicious` / `cached` | Counts. `notMalicious` is camelCase here — it's a count field, not the `not_malicious` enum value. |

## Allow list and block list

Same shapes for both lists; only the paths, plan availability and semantics differ.

- **Block list** (`/v1/block-list`, every plan): a blocked URL/host/domain/IP is always
  returned as `malicious` with reason `BLOCK_LIST_MATCH`.
- **Allow list** (`/v1/allow-list`, Pro & Business only): an allowed entry is returned as
  `not_malicious`, unless it is confirmed malicious — then it's `suspicious` with reason
  `ALLOW_LIST_CONFLICT`.
- Entries are private to the tenant. Writes take effect within about a minute.

### `GET` — list (newest first)

Query: `limit` (1–500, default 100), `cursor` (the previous page's `nextCursor`, ≤ 256 chars).

```json
{
  "entries": [
    { "id": "le_5b1e2d3c4f5a6b7c8d9e0f1a2b3c4d5e", "matchType": "domain",
      "value": "malicious-example.com", "createdAt": "2026-09-01T09:30:00Z" }
  ],
  "nextCursor": null
}
```

`nextCursor` is `null` on the last page.

### `POST` — add (needs `admin` scope)

```json
{ "matchType": "domain", "value": "malicious-example.com" }
```

| Field | Notes |
|---|---|
| `matchType` | `"url"` (exact URL) \| `"host"` (hostname) \| `"domain"` (registrable domain, including subdomains) \| `"ip"` |
| `value` | 1–2048 chars. |

Returns the `ListEntry` — `201` if created, `200` if an identical entry already existed
(adding is idempotent; both are success). For `url` entries the returned `value` shows only the
registrable domain and a short hash hint.

### `DELETE /{entryId}` — remove (needs `admin` scope)

`204 No Content` on success (no body — don't try to parse one), `404 not_found` if the entry
doesn't exist for this tenant. `entryId` is 1–64 chars.

## Billing (human-in-the-loop)

`POST /v1/billing/checkout` with `{ "planId": "pro" | "business", "turnstileToken": "<token>" }`
and `POST /v1/billing/portal` (no body) each return `{ "url": "https://..." }`. Both need an
`admin`-scope key. They exist so a person can start a subscription or manage billing: **an
autonomous agent should hand the URL to a human, never complete checkout itself.** The
checkout call also needs a bot-challenge (Turnstile) token minted by the checkout-start page,
so it is only callable from a flow that has a real browser in the loop. These are deliberately
left out of the MCP server's tool surface.

## `GET /health`

`{ "status": "ok" }`, no key needed. Liveness only — it says nothing about the freshness of the
data behind verdicts.

## Errors

Every non-2xx response from a keyed operation has one shape:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Too many requests. Retry after the interval in Retry-After.",
    "requestId": "req_01j9z8qaenp0s2c4d6f8g0h1jk"
  }
}
```

`code` is a closed set — branch on it, never on `message`:

| HTTP | `error.code` | Meaning | Retry? |
|---|---|---|---|
| 400 | `invalid_request` | Malformed JSON, bad field, unparseable target, or body over 8 KB. | No |
| 401 | `unauthorized` | API key missing, malformed, unknown or revoked. | No |
| 402 | `payment_required` | Tenant suspended for non-payment. | No |
| 403 | `forbidden` | Key lacks the required scope (e.g. `admin`). | No |
| 403 | `plan_feature_unavailable` | The plan doesn't include this feature (e.g. allow list on a free plan). | No |
| 404 | `not_found` | Resource doesn't exist for this tenant. | No |
| 429 | `rate_limited` | Per-minute limit exceeded. | Yes, after `Retry-After` seconds |
| 429 | `quota_exceeded` | Monthly quota exhausted. | No — won't clear until the quota resets or the plan changes |
| 503 | `auth_unavailable` | Auth backend briefly unavailable for a key not seen recently. | Yes, shortly |
| 500 | `internal` | Unexpected failure. Never contains stack traces or upstream bodies. | Yes, with backoff |

429 responses carry `Retry-After`, `RateLimit-Limit`, `RateLimit-Remaining` and
`RateLimit-Reset` (seconds until reset). For `quota_exceeded`, `RateLimit-Limit` is the monthly
limit rather than the per-minute one.

> **Changed from earlier drafts:** `invalid_target` → `invalid_request`, `invalid_api_key` →
> `unauthorized`, `tenant_suspended` → `payment_required`; `forbidden`, `not_found`,
> `plan_feature_unavailable`, `quota_exceeded` and `auth_unavailable` are new, and quota
> exhaustion is now `429 quota_exceeded` rather than a 402.

## Suggested client behavior (all SDKs in this repo follow this)

- Configurable base URL, defaulting to `https://api.skanqrcode.com`.
- A short request timeout (5s) — `checkUrl` gates a synchronous "open this URL?" decision, so a
  hung request shouldn't hang the caller.
- Typed errors: surface `error.code` / `error.message` / `error.requestId`, plus the HTTP
  status and (for 429s) `Retry-After` seconds, rather than a generic HTTP exception. If the
  error body isn't the documented JSON (a proxy's HTML 502, say) still raise the typed error,
  with a synthetic `internal` code and the HTTP status.
- Treat `204` as success with no body; treat both `200` and `201` from the add-entry calls as
  success.
- `action` is the thing to branch on. Each SDK also has a `shouldBlock`/`isSafe`-style helper
  (`action == block` / `action == allow`) for callers who just want a yes/no. `warn` is neither
  — surface it to the user.
- Don't retry 400/401/402/403/404 or `quota_exceeded`. Retry `rate_limited` after
  `Retry-After` (with jitter), `auth_unavailable` shortly, and 5xx with backoff. The SDKs
  themselves don't retry automatically — they expose `retryAfter` so the caller decides.
- Fail closed in UI code: if a check errors or times out, don't auto-open the link.
- Treat `environment == "sandbox"` / `licensedForProduction == false` results as
  integration-test output only.
