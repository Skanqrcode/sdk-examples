# @skanqrcode/mcp-server-example

A reference MCP server that exposes one tool, `check_url`, wrapping `POST /v1/check` from
[`../../docs/api-contract.md`](../../docs/api-contract.md). It talks stdio, so it works with
Claude Desktop, Claude Code, Cursor, or any other MCP client that spawns a local process.

This is example code, not the official `@skanqrcode/mcp-server` package advertised on
[skanqrcode.com/mcp](https://skanqrcode.com/mcp) — see [`../README.md`](../README.md) for why.

## Run it

```bash
npm install
npm run build
SKANQRCODE_API_KEY=lure_test_... npm start
```

## Wire it into an MCP client

```json
{
  "mcpServers": {
    "skanqrcode": {
      "command": "node",
      "args": ["/absolute/path/to/mcp/server/dist/index.js"],
      "env": { "SKANQRCODE_API_KEY": "lure_test_..." }
    }
  }
}
```

Once published to npm, this would collapse to `"command": "npx", "args": ["-y",
"@skanqrcode/mcp-server-example"]` the way the landing page's snippet does.

## Environment variables

| Variable | Required | Default |
|---|---|---|
| `SKANQRCODE_API_KEY` | yes | — |
| `SKANQRCODE_BASE_URL` | no | `https://api.skanqrcode.com` |
