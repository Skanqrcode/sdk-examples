import { z } from "zod";

/** Sent in the User-Agent so the API can report MCP traffic apart from direct calls. Keep equal to package.json. */
export const VERSION = "1.0.0";

const verdict = z.enum(["not_malicious", "suspicious", "malicious"]);

// Loose objects on purpose: a field the API adds later passes through instead of breaking the tool.
// Reason codes stay plain strings for the same reason (new codes are added over time).
export const checkResultShape = {
  verdict,
  action: z.enum(["allow", "warn", "block"]),
  mode: z.enum(["url", "ip"]),
  reasons: z.array(z.string()),
  finalUrl: z.string().nullable(),
  cached: z.boolean(),
  executionTimeMs: z.number().int(),
  environment: z.enum(["sandbox", "production"]),
  licensedForProduction: z.boolean(),
  requestId: z.string(),
  related: z.array(z.looseObject({ host: z.string(), verdict })).optional(),
};
const checkResultSchema = z.looseObject(checkResultShape);
export type CheckResult = z.infer<typeof checkResultSchema>;

export const usageShape = {
  tenantId: z.string(),
  month: z.string(),
  monthlyQuota: z.number().int(),
  totalRequests: z.number().int(),
  availableRequests: z.number().int(),
};
const usageSchema = z.looseObject(usageShape);
export type Usage = z.infer<typeof usageSchema>;

const errorBodySchema = z.object({
  error: z.object({ code: z.string(), message: z.string(), requestId: z.string().optional() }),
});

/** An API or transport failure, shaped so an agent can branch on `code` instead of parsing text. */
export class ApiError extends Error {
  readonly code: string;
  readonly status: number | null;
  readonly requestId: string | undefined;
  readonly retryAfterSeconds: number | undefined;

  constructor(
    code: string,
    message: string,
    details: { status?: number; requestId?: string | undefined; retryAfterSeconds?: number | undefined } = {},
  ) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = details.status ?? null;
    this.requestId = details.requestId;
    this.retryAfterSeconds = details.retryAfterSeconds;
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.requestId ? { requestId: this.requestId } : {}),
        ...(this.retryAfterSeconds !== undefined ? { retryAfterSeconds: this.retryAfterSeconds } : {}),
      },
    };
  }
}

export interface ApiClient {
  checkUrl(input: { target: string; userId?: string | undefined }): Promise<CheckResult>;
  getUsage(input: { month?: string | undefined }): Promise<Usage>;
}

export interface ApiClientOptions {
  apiKey: string;
  baseUrl: string;
  fetch?: typeof fetch;
  timeoutMs?: number;
}

export function createApiClient(options: ApiClientOptions): ApiClient {
  const doFetch = options.fetch ?? fetch;
  const timeoutMs = options.timeoutMs ?? 10_000;
  const userAgent = `skanqrcode-mcp-server/${VERSION} (node ${process.versions.node})`;

  async function call<T>(path: string, init: RequestInit, schema: z.ZodType<T>): Promise<T> {
    let res: Response;
    try {
      res = await doFetch(`${options.baseUrl}${path}`, {
        ...init,
        headers: {
          Authorization: `Bearer ${options.apiKey}`,
          "User-Agent": userAgent,
          Accept: "application/json",
          ...(init.body ? { "Content-Type": "application/json" } : {}),
        },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (err) {
      // Never include the request in the message: it would carry the checked URL.
      const timedOut = err instanceof Error && err.name === "TimeoutError";
      throw timedOut
        ? new ApiError("timeout", `SkanQRCode did not answer within ${timeoutMs / 1000}s. Try again.`)
        : new ApiError("network_error", "Could not reach SkanQRCode. Check the network and try again.");
    }

    const body: unknown = await res.json().catch(() => null);
    if (!res.ok) {
      const parsed = errorBodySchema.safeParse(body);
      const retryAfter = Number(res.headers.get("retry-after"));
      throw new ApiError(
        parsed.success ? parsed.data.error.code : res.status >= 500 ? "internal" : "http_error",
        parsed.success ? parsed.data.error.message : `SkanQRCode returned HTTP ${res.status}.`,
        {
          status: res.status,
          requestId: parsed.success ? parsed.data.error.requestId : undefined,
          retryAfterSeconds: Number.isFinite(retryAfter) && retryAfter > 0 ? retryAfter : undefined,
        },
      );
    }
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      throw new ApiError("unexpected_response", "SkanQRCode returned a response this server does not understand. Update @skanqrcode/mcp-server.", {
        status: res.status,
      });
    }
    return parsed.data;
  }

  return {
    checkUrl: ({ target, userId }) =>
      call("/v1/check", { method: "POST", body: JSON.stringify(userId ? { target, userId } : { target }) }, checkResultSchema),
    getUsage: ({ month }) =>
      call(`/v1/usage${month ? `?month=${encodeURIComponent(month)}` : ""}`, { method: "GET" }, usageSchema),
  };
}
