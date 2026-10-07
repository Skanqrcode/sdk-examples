#!/usr/bin/env node
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createApiClient } from "./api.ts";
import { loadConfig } from "./config.ts";
import { createServer } from "./server.ts";

// stdout carries the MCP protocol; anything else written there breaks the client. Diagnostics go to stderr.
const loaded = loadConfig(process.env);
if (!loaded.ok) {
  console.error(`skanqrcode-mcp-server: ${loaded.error}`);
  process.exit(1);
}

const server = createServer(createApiClient(loaded.config));
await server.connect(new StdioServerTransport());
