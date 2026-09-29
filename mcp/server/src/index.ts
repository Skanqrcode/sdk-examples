#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_KEY = process.env.SKANQRCODE_API_KEY;
if (!API_KEY) {
  console.error("SKANQRCODE_API_KEY is not set");
  process.exit(1);
}

const BASE_URL = process.env.SKANQRCODE_BASE_URL ?? "https://api.skanqrcode.com";

type Verdict = "malicious" | "suspicious" | "not_malicious";
type Recommendation = "proceed" | "warn" | "block";

interface CheckResult {
  verdict: Verdict;
  mode: "url" | "ip";
  score: number;
  reasons: string[];
  cached: boolean;
  partial: boolean;
  requestId: string;
}

interface ErrorResponse {
  error: { code: string; message: string; requestId: string };
}

function recommendationFor(verdict: Verdict): Recommendation {
  switch (verdict) {
    case "not_malicious":
      return "proceed";
    case "suspicious":
      return "warn";
    case "malicious":
      return "block";
  }
}

async function checkUrl(target: string): Promise<CheckResult & { recommendation: Recommendation }> {
  const res = await fetch(`${BASE_URL}/v1/check`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${API_KEY}`,
    },
    body: JSON.stringify({ target }),
    signal: AbortSignal.timeout(5000),
  });

  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as ErrorResponse | null;
    const message = body?.error?.message ?? `HTTP ${res.status}`;
    throw new Error(`SkanQRCode check failed: ${message}`);
  }

  const result = (await res.json()) as CheckResult;
  return { ...result, recommendation: recommendationFor(result.verdict) };
}

const server = new McpServer({
  name: "skanqrcode-mcp-server-example",
  version: "0.1.0",
});

server.tool(
  "check_url",
  "Evaluates whether a URL or IP address is safe to fetch, open, or scan. Call this before " +
    "fetching a URL from an untrusted source (a QR code payload, a message, a scraped page) so " +
    "you can abort instead of following a phishing or malware link. Consumes one unit of the " +
    "caller's monthly SkanQRCode quota per call, including cache hits. Returns a verdict " +
    "(malicious/suspicious/not_malicious) and a recommendation (block/warn/proceed) — branch on " +
    "`recommendation`, not just `verdict`.",
  {
    target: z.string().max(4096).describe("The URL or IP address to classify."),
  },
  async ({ target }) => {
    try {
      const result = await checkUrl(target);
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    } catch (err) {
      return {
        content: [{ type: "text", text: err instanceof Error ? err.message : String(err) }],
        isError: true,
      };
    }
  },
);

const transport = new StdioServerTransport();
await server.connect(transport);
