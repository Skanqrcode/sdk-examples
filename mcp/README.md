# SkanQRCode MCP examples

This directory has two parts:

- **[`server/`](server)**: the official `@skanqrcode/mcp-server` package, published to npm. Its
  [README](server/README.md) covers setup for Claude Desktop, Claude Code and Cursor.
- **[`clients/`](clients)**: how to *call* the `check_url` tool from code, for an agent you're
  building yourself.

## The `check_url` tool

Input:

```json
{ "target": "https://example.com/login", "userId": "user-4821" }
```

`target` (1–4096 chars) is required. `userId` (1–128 chars) is optional: an opaque end-user
identifier that enables per-user result caching; the API hashes it before use.

Output: the `/v1/check` response, as MCP structured content and as a JSON text block for
clients that don't read structured content yet:

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

On failure the tool returns `isError: true` with
`{ "error": { "code", "message", "requestId", "retryAfterSeconds" } }`, so an agent can branch on `code`.

The server also has a `get_usage` tool (monthly quota, used and remaining); see
[`server/README.md`](server/README.md).

### What's deliberately not a tool

The spec marks billing as human-in-the-loop (an agent should hand a checkout/portal URL to a
person, never complete checkout itself) and the webhook as not part of the agent surface. The
allow/block-list write endpoints change enforcement for the whole tenant, and text an agent reads
can try to steer it: an agent that could add allow-list entries could be talked into approving a
phishing domain. So the server is read-only; manage lists in the dashboard.

## Claude Desktop / generic MCP client config

```json
{
  "mcpServers": {
    "skanqrcode": {
      "command": "npx",
      "args": ["-y", "@skanqrcode/mcp-server"],
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
