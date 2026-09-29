// Calls the skanqrcode MCP server's `check_url` tool directly from an agent you're building,
// instead of going through Claude Desktop's config UI. Requires the server already built:
// see ../server/README.md.
//
//   npm install @modelcontextprotocol/sdk
//   SKANQRCODE_API_KEY=lure_test_... npx tsx typescript.ts "https://example.com/login"

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const target = process.argv[2];
if (!target) {
  console.error("usage: typescript.ts <url-or-ip>");
  process.exit(1);
}

const transport = new StdioClientTransport({
  command: "node",
  args: ["../server/dist/index.js"],
  env: { SKANQRCODE_API_KEY: process.env.SKANQRCODE_API_KEY ?? "" },
});

const client = new Client({ name: "skanqrcode-mcp-client-example", version: "0.1.0" });
await client.connect(transport);

const result = await client.callTool({
  name: "check_url",
  arguments: { target },
});

if (result.isError) {
  console.error("check_url failed:", result.content);
  process.exit(1);
}

const [block] = result.content as Array<{ type: "text"; text: string }>;
const parsed = JSON.parse(block.text);

console.log(parsed);
if (parsed.recommendation === "block") {
  console.error(`Refusing to fetch ${target}: ${parsed.reasons.join(", ")}`);
  process.exit(1);
}

await client.close();
