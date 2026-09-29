# SkanQRCode API — contract used by these examples

This is the exact request/response shape every example and SDK package in this repo codes
against. It is copied from `skanqrcode-api/docs/openapi.yaml` (OpenAPI 3.1, generated from the
live Zod schemas) and `skanqrcode-api/CLAUDE.md`, which that repo declares as the source of
truth for the HTTP contract.

## Why this doc exists

The public marketing pages (`skanqrcode.com`, `skanqrcode.com/mcp`) describe a **different**
shape than the engineering spec:

| | Marketing copy (skanqrcode.com) | Engineering spec (openapi.yaml) — used here |
|---|---|---|
| Request body | `{"content": "<url>"}` | `{"target": "<url-or-ip>"}` |
| Response | `{verdict, action, reason, recommended_agent_action}` | `{verdict, mode, score, reasons[], cached, partial, requestId}` |
| API key prefix | `sk_test_...` | `lure_live_...` / `lure_test_...` |
| MCP server | `@skanqrcode/mcp-server` on npm, tool `check_url` | Not present in the repo; explicitly "not authorized" per CLAUDE.md §15 |

There's no implementation code in `skanqrcode-api` yet — only the spec and the CLAUDE.md — so
the openapi.yaml contract is the only one that's actually engineered and reviewed. These
examples follow it. **If `api.skanqrcode.com` turns out to speak the marketing dialect instead,
the fix is mechanical**: rename `target`→`content` in the request and remap the response fields
in each SDK's `checkUrl`/`CheckUrl`/`check_url` method — the surrounding client code (auth,
retries, mobile integration, MCP tool wiring) doesn't change.

The MCP server under [`mcp/server`](../mcp/server) is a reference implementation that wraps this
same contract — treat it as example code to adapt once the real `@skanqrcode/mcp-server` package
or its actual tool schema is confirmed, not as a drop-in replacement for it.

## Base URL

```
https://api.skanqrcode.com
```

## Authentication

Every operation except `GET /health` and `GET /openapi.json` requires an API key:

```
Authorization: Bearer <API_KEY>
```

- Production keys: `lure_live_<id>_<secret>`
- Test/sandbox keys: `lure_test_<id>_<secret>`
- Never send the key as a query parameter — it isn't supported and would leak into logs/proxies.

All examples read the key from an environment variable, `SKANQRCODE_API_KEY`, rather than
hardcoding it.

## `POST /v1/check`

Classifies a single URL or IP address. This is the hot path — call it before letting a user
follow a link, opening a QR-code payload, or accepting an inbound connection from an
untrusted IP. It answers within a ~180ms internal deadline; if a signal source is slow, the
response still comes back with `partial: true` rather than blocking. It never returns an HTTP
error for a well-formed-but-unrecognized target — only for malformed input (400) or
auth/quota/billing failures.

**Consumes one unit of the tenant's monthly quota per call, including cache hits.**

### Request

```json
{ "target": "https://example.com/login" }
```

| Field | Type | Notes |
|---|---|---|
| `target` | string, required, ≤ 4096 chars | A URL or IPv4/IPv6 address to classify. |

### Response — `200 OK`

```json
{
  "verdict": "malicious",
  "mode": "url",
  "score": 97,
  "reasons": ["URLHAUS_ACTIVE", "WEBRISK_MALWARE"],
  "cached": false,
  "partial": true,
  "requestId": "req_01J9Z8QAENP0S2"
}
```

| Field | Type | Notes |
|---|---|---|
| `verdict` | `"malicious" \| "suspicious" \| "not_malicious"` | The decision. |
| `mode` | `"url" \| "ip"` | What kind of target was classified. |
| `score` | integer 0–100 | Weighted heuristic score backing the verdict. |
| `reasons` | string[] | Closed set of reason codes that contributed. |
| `cached` | boolean | `true` if served from the per-user verdict cache. |
| `partial` | boolean | `true` if a signal source missed the internal deadline. |
| `requestId` | string | Correlates this response with server-side logs/support requests. |

Response headers worth reading: `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`,
`Server-Timing`, `X-Request-Id`.

### Error responses

All non-2xx responses share one shape:

```json
{
  "error": {
    "code": "invalid_target",
    "message": "target could not be parsed as a URL or IP address.",
    "requestId": "req_01J9Z8QAENP0S2"
  }
}
```

| HTTP status | `error.code` | Meaning |
|---|---|---|
| 400 | `invalid_target` | Body failed validation (unparseable, or `target` over 4096 chars). |
| 401 | `invalid_api_key` | Missing, malformed, or revoked API key. |
| 402 | `tenant_suspended` | Subscription past due beyond grace period, or quota exhausted with overage disabled. |
| 429 | `rate_limited` | Rate limit or monthly quota exceeded. Respect the `Retry-After` header. |
| 5xx | (varies) | Unexpected server-side failure. Never contains stack traces or upstream error bodies. |

A well-behaved client retries 429s after `Retry-After` seconds (with jitter), does **not**
retry 400/401/402, and treats 5xx as retryable with backoff.

## `GET /v1/usage?from=<rfc3339>&to=<rfc3339>`

Returns hourly usage/verdict aggregates for the calling tenant. Lags real-time usage by up to
about an hour (it reads D1 billing-source-of-truth aggregates, not the fast-path quota
counter). `from` is inclusive, `to` is exclusive, both RFC 3339 UTC timestamps.

### Response — `200 OK`

```json
{
  "tenantId": "ten_01J9Z2K3F5G6H7",
  "from": "2026-09-01T00:00:00Z",
  "to": "2026-09-02T00:00:00Z",
  "hours": [
    {
      "hour": "2026-09-01T00:00:00Z",
      "mode": "url",
      "total": 1042,
      "malicious": 12,
      "suspicious": 30,
      "notMalicious": 1000,
      "cached": 811,
      "partial": 2
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `tenantId` | string | Always the authenticated tenant — never another tenant's data. |
| `from`, `to` | string (RFC 3339) | Echoes the requested range. |
| `hours` | array | One entry per `(hour, mode)` bucket that had activity. |
| `hours[].hour` | string (RFC 3339) | Start of the UTC hour bucket. |
| `hours[].mode` | `"url" \| "ip"` | |
| `hours[].total` | integer | Total checks in this bucket. |
| `hours[].malicious`, `.suspicious`, `.notMalicious` | integer | Verdict breakdown; note `notMalicious` is camelCase here (this is a response body field, not a Verdict enum value — the enum value is `not_malicious`, this count field is `notMalicious`). |
| `hours[].cached` | integer | How many of `total` were cache hits. |
| `hours[].partial` | integer | How many of `total` had `partial: true`. |

See each SDK's `getUsage`/`GetUsage`/`get_usage` method for the typed response — field names
follow this shape exactly (adapted to each language's casing convention, e.g. `not_malicious`
in Python/Rust/Dart, `notMalicious` in TS/JS/Kotlin/Java/Go-as-JSON-tag).

## Suggested client behavior (all SDKs in this repo follow this)

- Configurable base URL, defaulting to `https://api.skanqrcode.com`.
- A short request timeout (5s) — this call is meant to gate a synchronous "open this URL?"
  decision, so a hung request shouldn't hang the caller indefinitely.
- Typed errors: surface `error.code`/`error.message`/`error.requestId` rather than a generic
  HTTP exception, so callers can branch on `code`.
- A convenience `shouldBlock` / `isSafe`-style helper alongside the raw `verdict`, for callers
  that just want an allow/warn/block decision without switching on the enum themselves.
