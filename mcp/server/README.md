# @skanqrcode/mcp-server

The official [SkanQRCode](https://skanqrcode.com) MCP server. It gives an AI agent a URL safety
check to run **before** it fetches, opens or hands a user a link from an untrusted source: a QR
code, an email, a chat message, a web page or another tool's output.

It runs locally over stdio, so it works with Claude Desktop, Claude Code, Cursor, Windsurf and
any other MCP client that starts a local process.

## Setup

1. Create an API key at [app.skanqrcode.com](https://app.skanqrcode.com). The free plan gives you
   an `sk_test_` key with 1,000 checks a month, no card required.
2. Add the server to your MCP client.

**Claude Desktop** (`claude_desktop_config.json`), Cursor and most other clients:

```json
{
  "mcpServers": {
    "skanqrcode": {
      "command": "npx",
      "args": ["-y", "@skanqrcode/mcp-server"],
      "env": { "SKANQRCODE_API_KEY": "sk_test_..." }
    }
  }
}
```

**Claude Code:**

```bash
claude mcp add skanqrcode --env SKANQRCODE_API_KEY=sk_test_... -- npx -y @skanqrcode/mcp-server
```

Requires Node.js 20 or later.

## Tools

### `check_url`

Classifies a URL or IP address. Input:

| Field | Required | Description |
|---|---|---|
| `target` | yes | The full URL (with scheme) or IP address, up to 4,096 characters. |
| `userId` | no | Opaque id of the end user the check is for, for per-user caching. Never an email or a name. |

Returns the API's verdict as structured content:

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

The agent should branch on `action`: `block` means do not fetch or open it, `warn` means ask the
user first, `allow` means go ahead. Each call uses one unit of your monthly quota.

### `get_usage`

Returns the monthly quota, requests used and requests left (optional `month` as `YYYY-MM`). It
does not use quota.

### Errors

A failed call returns `isError: true` with
`{ "error": { "code": "...", "message": "...", "requestId": "...", "retryAfterSeconds": 12 } }`.
For `rate_limited`, wait `retryAfterSeconds`; for `quota_exceeded`, stop and tell the user.

### Why there are no list tools

The server is read-only. Text an agent reads can try to steer it, and an agent that could add
allow-list entries could be talked into approving a phishing domain. Manage allow and block lists
in the dashboard.

## Environment variables

| Variable | Required | Default |
|---|---|---|
| `SKANQRCODE_API_KEY` | yes | — |
| `SKANQRCODE_BASE_URL` | no | `https://api.skanqrcode.com` (must be `https://`) |

Your key is sent only to the API, only over HTTPS, and is never logged.

## Sandbox keys

With an `sk_test_` key the result says `environment: "sandbox"` and
`licensedForProduction: false`: the verdicts are real, but the free plan is licensed for testing
only. Use an `sk_live_` key from a paid plan in production.

## Development

```bash
npm install
npm test          # unit tests and an MCP client/server round trip
npm run build
SKANQRCODE_API_KEY=sk_test_... npx @modelcontextprotocol/inspector node dist/index.js
```

API reference: [docs.skanqrcode.com](https://docs.skanqrcode.com).
