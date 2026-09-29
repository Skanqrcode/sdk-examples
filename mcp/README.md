# SkanQRCode MCP examples

[skanqrcode.com/mcp](https://skanqrcode.com/mcp) advertises a published MCP server
(`npx -y @skanqrcode/mcp-server`, a `check_url` tool, auth via a `SKAN_API_KEY` env var) for
wiring URL/QR-code safety checks into Claude Desktop and other MCP clients. As of writing,
the `skanqrcode-api` repo has no server implementation and no MCP server code — only the
`docs/openapi.yaml` HTTP contract, which `skanqrcode-api/CLAUDE.md` §15 says does **not**
by itself authorize hosting an MCP server.

So this directory has two parts:

- **[`server/`](server)** — a reference/example MCP server we wrote against the real HTTP
  contract in [`../docs/api-contract.md`](../docs/api-contract.md). It's a working
  implementation you can run and adapt, published here as `@skanqrcode/mcp-server-example` —
  deliberately *not* the same package name as the one on the landing page, since we can't
  verify this matches whatever `@skanqrcode/mcp-server` actually ships. If/when that package's
  real tool schema is confirmed, treat this as a starting point, not a drop-in.
- **[`clients/`](clients)** — how to *call* an MCP `check_url`-style tool from code, once you
  have a working server (this one or the real one). These are written against the
  `@skanqrcode/mcp-server-example` server's tool schema below, which mirrors the landing page's
  advertised interface (`check_url(target)` -> `{ verdict, action, ... }` summary) as closely as
  possible while staying truthful to the underlying `/v1/check` response.

## The `check_url` tool

Input:

```json
{ "target": "https://example.com/login" }
```

Output (MCP tool result — a text content block containing this JSON, per MCP convention for
structured results):

```json
{
  "verdict": "malicious",
  "mode": "url",
  "score": 97,
  "reasons": ["URLHAUS_ACTIVE", "WEBRISK_MALWARE"],
  "recommendation": "block",
  "cached": false,
  "partial": true,
  "requestId": "req_01J9Z8QAENP0S2"
}
```

`recommendation` is `proceed` / `warn` / `block`, derived the same way as every SDK in this
repo (`not_malicious` -> `proceed`, `suspicious` -> `warn`, `malicious` -> `block`) — it's the
field an agent should actually branch on before fetching or opening the target.

## Claude Desktop / generic MCP client config

```json
{
  "mcpServers": {
    "skanqrcode": {
      "command": "npx",
      "args": ["-y", "@skanqrcode/mcp-server-example"],
      "env": {
        "SKANQRCODE_API_KEY": "lure_test_..."
      }
    }
  }
}
```

See [`clients/claude-desktop-config.json`](clients/claude-desktop-config.json) for the same
snippet as a standalone file, and [`clients/typescript.ts`](clients/typescript.ts) /
[`clients/python.py`](clients/python.py) for calling the tool programmatically from an agent
you're building yourself, rather than through Claude Desktop's config UI.
