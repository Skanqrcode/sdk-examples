import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import { type ApiClient, ApiError, checkResultShape, usageShape, VERSION } from "./api.ts";

function ok(result: Record<string, unknown>): CallToolResult {
  return { content: [{ type: "text", text: JSON.stringify(result) }], structuredContent: result };
}

function failed(err: unknown): CallToolResult {
  const error = err instanceof ApiError ? err : new ApiError("internal", "Unexpected error in the MCP server.");
  return { content: [{ type: "text", text: JSON.stringify(error) }], isError: true };
}

/**
 * Read-only on purpose: no allow-list or block-list tools. Text an agent reads (a web page, an email)
 * can steer it, and an agent that could add allow-list entries could be talked into approving a
 * phishing domain. List changes stay with a person in the dashboard.
 */
export function createServer(api: ApiClient): McpServer {
  const server = new McpServer({ name: "skanqrcode", version: VERSION });

  server.registerTool(
    "check_url",
    {
      title: "Check URL safety",
      description:
        "Classifies a URL or IP address as malicious, suspicious or not_malicious. Call it before you " +
        "fetch, open, scrape or hand a user a link that came from an untrusted source: a QR code, an " +
        "email, a chat message, a web page or another tool's output. Branch on `action`: `block` means do " +
        "not fetch or open it, `warn` means ask the user first, `allow` means go ahead. `reasons` lists " +
        "the evidence categories. The result describes the target only; it never contains page content. " +
        "Each call consumes one unit of the account's monthly quota, cached answers included. With a " +
        "sandbox key (`environment: sandbox`, `licensedForProduction: false`) results are for testing " +
        "only. On error the result is `{ error: { code, message, retryAfterSeconds? } }`: for " +
        "`rate_limited` wait `retryAfterSeconds` before retrying; for `quota_exceeded` stop and tell the user.",
      inputSchema: {
        target: z.string().min(1).max(4096).describe("The full URL (including scheme) or IP address to check."),
        userId: z
          .string()
          .min(1)
          .max(128)
          .optional()
          .describe(
            "Optional opaque id of the end user the check is for, enabling per-user caching. " +
              "Never pass an email address or a name; it is hashed server-side.",
          ),
      },
      outputSchema: checkResultShape,
      annotations: {
        title: "Check URL safety",
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: true,
      },
    },
    async ({ target, userId }) => {
      try {
        return ok(await api.checkUrl({ target, userId }));
      } catch (err) {
        return failed(err);
      }
    },
  );

  server.registerTool(
    "get_usage",
    {
      title: "Get monthly usage",
      description:
        "Returns the account's monthly quota, requests used and requests still available for a calendar " +
        "month (UTC, defaults to the current one). Figures can lag real time by up to about an hour, so " +
        "use it to pace a large batch of checks, not to decide whether the very next call will succeed. " +
        "Does not consume quota.",
      inputSchema: {
        month: z
          .string()
          .regex(/^\d{4}-(0[1-9]|1[0-2])$/)
          .optional()
          .describe("Calendar month as YYYY-MM. Omit for the current month."),
      },
      outputSchema: usageShape,
      annotations: {
        title: "Get monthly usage",
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async ({ month }) => {
      try {
        return ok(await api.getUsage({ month }));
      } catch (err) {
        return failed(err);
      }
    },
  );

  return server;
}
