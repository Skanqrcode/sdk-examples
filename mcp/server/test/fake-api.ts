export const CHECK_RESULT = {
  verdict: "malicious",
  action: "block",
  mode: "url",
  reasons: ["ACTIVE_THREAT_FEED_MATCH"],
  finalUrl: null,
  cached: false,
  executionTimeMs: 38,
  environment: "sandbox",
  licensedForProduction: false,
  requestId: "req_test",
} as const;

export const USAGE = {
  tenantId: "ten_test",
  month: "2026-10",
  monthlyQuota: 1000,
  totalRequests: 12,
  availableRequests: 988,
} as const;

export interface Captured {
  url: string;
  init: RequestInit;
}

/** A fetch that records each request and answers with the given status, body and headers. */
export function fakeFetch(
  status: number,
  body: unknown,
  headers: Record<string, string> = {},
): { fetch: typeof fetch; calls: Captured[] } {
  const calls: Captured[] = [];
  const impl = (async (input: string | URL | Request, init: RequestInit = {}) => {
    calls.push({ url: String(input), init });
    const text = typeof body === "string" ? body : JSON.stringify(body);
    return new Response(text, { status, headers: { "content-type": "application/json", ...headers } });
  }) as typeof fetch;
  return { fetch: impl, calls };
}
