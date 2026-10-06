# SkanQRCode MCP examples

This directory has two parts:

- **[`server/`](server)** — a reference MCP server written against the HTTP contract in
  [`../docs/api-contract.md`](../docs/api-contract.md). It's a working implementation you can
  run and adapt, published here as `@skanqrcode/mcp-server-example`. It is example code, not
  the official `@skanqrcode/mcp-server` package advertised on
  [skanqrcode.com/mcp](https://skanqrcode.com/mcp) — the tool schema and env var names there
  may differ from this one, so check them before swapping one for the other.
- **[`clients/`](clients)** — how to *call* a `check_url`-style MCP tool from code, once you
  have a working server. These are written against this server's tool schema below.

## The `check_url` tool

Input:

```json
{ "target": "https://example.com/login", "userId": "user-4821" }
```

`target` (1–4096 chars) is required. `userId` (1–128 chars) is optional: an opaque end-user
identifier that enables per-user result caching; the API hashes it before use.

Output (MCP tool result — a text content block containing the `/v1/check` response as JSON,
per MCP convention for structured results):

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

`action` is `allow` / `warn` / `block` and comes straight from the API (`not_malicious` →
`allow`, `suspicious` → `warn`, `malicious` → `block`) — it's the field an agent should branch
on before fetching or opening the target. For IP targets the result also carries a `related`
array of recently associated hosts.

Two fields worth having the agent respect:

- `environment: "sandbox"` / `licensedForProduction: false` — an `sk_test_` key; results are
  for integration testing, not production enforcement.

On failure the tool returns `isError: true` with a message that includes the API's error code,
its `requestId`, and the `Retry-After` seconds for a `rate_limited` 429.

### What's deliberately not a tool

The spec marks billing as human-in-the-loop (an agent should hand a checkout/portal URL to a
person, never complete checkout itself) and the webhook as not part of the agent surface. The
allow/block-list write endpoints need an `admin`-scope key and change enforcement for the whole
tenant, so they're also left out — add them only if you want an agent to have that power. If
you do, the SDKs under [`../sdk`](../sdk) already wrap them.

## Claude Desktop / generic MCP client config

```json
{
  "mcpServers": {
    "skanqrcode": {
      "command": "npx",
      "args": ["-y", "@skanqrcode/mcp-server-example"],
      "env": {
        "SKANQRCODE_API_KEY": "sk_test_..."
      }
    }
  }
}
```

See [`clients/claude-desktop-config.json`](clients/claude-desktop-config.json) for the same
snippet as a standalone file, and [`clients/typescript.ts`](clients/typescript.ts) /
[`clients/python.py`](clients/python.py) for calling the tool programmatically from an agent
you're building yourself, rather than through Claude Desktop's config UI.
