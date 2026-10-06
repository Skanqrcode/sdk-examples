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
type Action = "allow" | "warn" | "block";

interface CheckResult {
  verdict: Verdict;
  action: Action;
  mode: "url" | "ip";
  reasons: string[];
  finalUrl: string | null;
  cached: boolean;
  executionTimeMs: number;
  environment: "sandbox" | "production";
  licensedForProduction: boolean;
  requestId: string;
  related?: Array<{ host: string; verdict: Verdict }>;
}

interface ErrorResponse {
  error: { code: string; message: string; requestId: string };
}

async function checkUrl(target: string, userId?: string): Promise<CheckResult> {
  const res = await fetch(`${BASE_URL}/v1/check`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${API_KEY}`,
    },
    body: JSON.stringify(userId ? { target, userId } : { target }),
    signal: AbortSignal.timeout(5000),
  });

  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as ErrorResponse | null;
    const code = body?.error?.code ?? "internal";
    const message = body?.error?.message ?? `HTTP ${res.status}`;
    const retryAfter = res.headers.get("Retry-After");
    throw new Error(
      `SkanQRCode check failed (${code}): ${message}` +
        (retryAfter ? ` Retry after ${retryAfter}s.` : "") +
        (body?.error?.requestId ? ` [requestId ${body.error.requestId}]` : ""),
    );
  }

  return (await res.json()) as CheckResult;
}

const server = new McpServer({
  name: "skanqrcode-mcp-server-example",
  version: "0.2.0",
});

server.tool(
  "check_url",
  "Evaluates whether a URL or IP address is safe to fetch, open, or scan. Call this before " +
    "fetching a URL from an untrusted source (a QR code payload, a message, a scraped page) so " +
    "you can abort instead of following a phishing or malware link. Consumes one unit of the " +
    "caller's monthly SkanQRCode quota per call, including cache hits. Returns a verdict " +
    "(malicious/suspicious/not_malicious) and the recommended action (block/warn/allow) — branch " +
    "on `action`: block means do not fetch, warn means ask the user first. If `environment` is " +
    "`sandbox` (`licensedForProduction: false`) the result is for integration testing only.",
  {
    target: z.string().min(1).max(4096).describe("The URL or IP address to classify."),
    userId: z
      .string()
      .min(1)
      .max(128)
      .optional()
      .describe(
        "Optional opaque identifier of the end user this check is for; enables per-user result " +
          "caching. Hashed server-side, never stored in clear.",
      ),
  },
  async ({ target, userId }) => {
    try {
      const result = await checkUrl(target, userId);
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
