/**
 * @skanqrcode/sdk — typed client for the SkanQRCode API (OpenAPI 1.7.0).
 * Contract: ../../../docs/api-contract.md
 */

export type Verdict = "malicious" | "suspicious" | "not_malicious";
/** What the caller should do. Fixed mapping: not_malicious->allow, suspicious->warn, malicious->block. */
export type Action = "allow" | "warn" | "block";
export type Mode = "url" | "ip";
/** "sandbox" for sk_test_ keys, "production" for sk_live_ keys. */
export type Environment = "sandbox" | "production";
export type MatchType = "url" | "host" | "domain" | "ip";
export type PlanId = "pro" | "business";

/** Closed set of API error codes. Branch on this, never on `message`. */
export type ErrorCode =
  | "invalid_request"
  | "unauthorized"
  | "forbidden"
  | "not_found"
  | "plan_feature_unavailable"
  | "payment_required"
  | "rate_limited"
  | "quota_exceeded"
  | "auth_unavailable"
  | "internal";

/** The documented error codes, for runtime checks. */
export const ERROR_CODES: readonly ErrorCode[] = [
  "invalid_request",
  "unauthorized",
  "forbidden",
  "not_found",
  "plan_feature_unavailable",
  "payment_required",
  "rate_limited",
  "quota_exceeded",
  "auth_unavailable",
  "internal",
];

/** One host associated with an IP target (IP mode only). */
export interface RelatedHost {
  host: string;
  verdict: Verdict;
}

export interface CheckResult {
  verdict: Verdict;
  /** Branch on this: allow / warn / block. */
  action: Action;
  mode: Mode;
  /** Reason codes (plain strings, so new codes don't break parsing). See the contract for the current set. */
  reasons: string[];
  /** Where a shortened link resolved to, if a redirect was followed. */
  finalUrl: string | null;
  /** True only if served from this tenant's own per-user cache. */
  cached: boolean;
  /** Server-side evaluation time in milliseconds. */
  executionTimeMs: number;
  environment: Environment;
  /** False on the free sandbox plan. Never changes verdict/action. */
  licensedForProduction: boolean;
  /** Quote this to support. */
  requestId: string;
  /** IP mode only: recently associated hosts, most recent first (at most 20). */
  related?: RelatedHost[];
}

export interface UsageResponse {
  tenantId: string;
  /** UTC calendar month, YYYY-MM. */
  month: string;
  monthlyQuota: number;
  totalRequests: number;
  /** max(monthlyQuota - totalRequests, 0). */
  availableRequests: number;
}

export interface UsageHour {
  /** RFC3339 timestamp marking the start of the hour this bucket covers. */
  hour: string;
  mode: Mode;
  total: number;
  /** total / hourlyCapacity * 100, one decimal. Near 100 means that hour ran at the rate limit. */
  capacityUsedPercent: number;
  /** Requests blocked that hour for exceeding the per-minute limit. */
  blockedRpm: number;
  /** Requests blocked that hour for exceeding the monthly quota. */
  blockedQuota: number;
  malicious: number;
  suspicious: number;
  notMalicious: number;
  cached: number;
}

export interface UsageHourlyResponse {
  tenantId: string;
  month: string;
  /** The plan's requests-per-minute limit. */
  rpmLimit: number;
  /** rpmLimit * 60. A reading aid only; limits are enforced per minute. */
  hourlyCapacity: number;
  hours: UsageHour[];
}

export interface ListEntry {
  id: string;
  matchType: MatchType;
  value: string;
  /** RFC3339 timestamp. */
  createdAt: string;
}

export interface ListPage {
  entries: ListEntry[];
  /** Pass as `cursor` to get the next page; null on the last page. */
  nextCursor: string | null;
}

export interface SessionResponse {
  url: string;
}

export interface HealthResponse {
  status: "ok";
}

interface ApiErrorBody {
  error: {
    code: string;
    message: string;
    requestId: string;
  };
}

export class SkanQRCodeError extends Error {
  /** One of ErrorCode. Typed loosely so an unknown code still works at runtime. */
  readonly code: ErrorCode | (string & {});
  readonly requestId: string;
  readonly status: number;
  /** Seconds from the Retry-After header (429s), or null if absent. */
  readonly retryAfter: number | null;

  constructor(
    code: ErrorCode | (string & {}),
    message: string,
    requestId: string,
    status: number,
    retryAfter: number | null = null,
  ) {
    super(message);
    this.name = "SkanQRCodeError";
    this.code = code;
    this.requestId = requestId;
    this.status = status;
    this.retryAfter = retryAfter;
  }
}

export interface SkanQRCodeClientOptions {
  /** sk_test_... (sandbox) or sk_live_... (production). */
  apiKey: string;
  baseUrl?: string;
  timeoutMs?: number;
}

const DEFAULT_BASE_URL = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT_MS = 5000;

function query(params: Record<string, string | number | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined) search.set(key, String(value));
  }
  const qs = search.toString();
  return qs ? `?${qs}` : "";
}

export class SkanQRCodeClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(options: SkanQRCodeClientOptions) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  /** POST /v1/check. Consumes one quota unit. `userId` (opaque, 1-128 chars) enables per-user caching. */
  async checkUrl(target: string, userId?: string): Promise<CheckResult> {
    const body: { target: string; userId?: string } = { target };
    if (userId !== undefined) body.userId = userId;
    return this.request<CheckResult>("/v1/check", {
      method: "POST",
      body: JSON.stringify(body),
    });
  }

  /** GET /v1/usage. `month` is YYYY-MM (UTC); defaults to the current month. */
  async getUsage(month?: string): Promise<UsageResponse> {
    return this.request<UsageResponse>(`/v1/usage${query({ month })}`, {
      method: "GET",
    });
  }

  /** GET /v1/usage/hourly. `month` is YYYY-MM (UTC); defaults to the current month. */
  async getUsageHourly(month?: string): Promise<UsageHourlyResponse> {
    return this.request<UsageHourlyResponse>(`/v1/usage/hourly${query({ month })}`, {
      method: "GET",
    });
  }

  /** GET /v1/allow-list (Pro & Business plans only). `limit` is 1-500, default 100. */
  async listAllowList(limit?: number, cursor?: string): Promise<ListPage> {
    return this.request<ListPage>(`/v1/allow-list${query({ limit, cursor })}`, {
      method: "GET",
    });
  }

  /** POST /v1/allow-list (Pro & Business plans only; needs an admin-scope key). Idempotent. */
  async addAllowListEntry(matchType: MatchType, value: string): Promise<ListEntry> {
    return this.request<ListEntry>("/v1/allow-list", {
      method: "POST",
      body: JSON.stringify({ matchType, value }),
    });
  }

  /** DELETE /v1/allow-list/{entryId} (Pro & Business plans only; needs an admin-scope key). */
  async deleteAllowListEntry(entryId: string): Promise<void> {
    await this.request<void>(`/v1/allow-list/${encodeURIComponent(entryId)}`, {
      method: "DELETE",
    });
  }

  /** GET /v1/block-list (every plan). `limit` is 1-500, default 100. */
  async listBlockList(limit?: number, cursor?: string): Promise<ListPage> {
    return this.request<ListPage>(`/v1/block-list${query({ limit, cursor })}`, {
      method: "GET",
    });
  }

  /** POST /v1/block-list (every plan; needs an admin-scope key). Idempotent. */
  async addBlockListEntry(matchType: MatchType, value: string): Promise<ListEntry> {
    return this.request<ListEntry>("/v1/block-list", {
      method: "POST",
      body: JSON.stringify({ matchType, value }),
    });
  }

  /** DELETE /v1/block-list/{entryId} (every plan; needs an admin-scope key). */
  async deleteBlockListEntry(entryId: string): Promise<void> {
    await this.request<void>(`/v1/block-list/${encodeURIComponent(entryId)}`, {
      method: "DELETE",
    });
  }

  /**
   * POST /v1/billing/checkout. Needs an admin-scope key and a Turnstile token minted by a real
   * browser flow. Human-in-the-loop: hand the returned URL to a person; an autonomous agent
   * must never complete checkout itself.
   */
  async createCheckoutSession(planId: PlanId, turnstileToken: string): Promise<SessionResponse> {
    return this.request<SessionResponse>("/v1/billing/checkout", {
      method: "POST",
      body: JSON.stringify({ planId, turnstileToken }),
    });
  }

  /**
   * POST /v1/billing/portal. Needs an admin-scope key. Human-in-the-loop: hand the returned URL
   * to a person.
   */
  async createPortalSession(): Promise<SessionResponse> {
    return this.request<SessionResponse>("/v1/billing/portal", {
      method: "POST",
    });
  }

  /** GET /health. Liveness only; needs no API key. */
  async getHealth(): Promise<HealthResponse> {
    return this.request<HealthResponse>("/health", { method: "GET" }, false);
  }

  private async request<T>(path: string, init: RequestInit, auth = true): Promise<T> {
    const headers: Record<string, string> = {};
    if (init.body !== undefined) headers["Content-Type"] = "application/json";
    if (auth) headers.Authorization = `Bearer ${this.apiKey}`;

    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers,
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      throw await this.toError(response);
    }

    // 204 No Content (deletes): success, nothing to parse.
    if (response.status === 204) {
      return undefined as T;
    }

    return (await response.json()) as T;
  }

  /** Builds the typed error; falls back to a synthetic `internal` if the body isn't the documented JSON. */
  private async toError(response: Response): Promise<SkanQRCodeError> {
    const retryAfterHeader = response.headers.get("Retry-After");
    const retryAfterSeconds = retryAfterHeader === null ? NaN : Number(retryAfterHeader);
    const retryAfter = Number.isFinite(retryAfterSeconds) ? retryAfterSeconds : null;

    let body: Partial<ApiErrorBody> | undefined;
    try {
      body = JSON.parse(await response.text()) as Partial<ApiErrorBody>;
    } catch {
      body = undefined;
    }

    const err = body?.error;
    if (err && typeof err.code === "string") {
      return new SkanQRCodeError(
        err.code,
        err.message ?? "",
        err.requestId ?? response.headers.get("X-Request-Id") ?? "",
        response.status,
        retryAfter,
      );
    }

    return new SkanQRCodeError(
      "internal",
      `Unexpected ${response.status} response from the API (body was not the documented error JSON).`,
      response.headers.get("X-Request-Id") ?? "",
      response.status,
      retryAfter,
    );
  }
}

/** not_malicious -> allow, suspicious -> warn, malicious -> block. True only for `block`. */
export function shouldBlock(result: CheckResult): boolean {
  return result.action === "block";
}

/** True only for `allow`; `warn` is neither safe nor blocked, so surface it to the user. */
export function isSafe(result: CheckResult): boolean {
  return result.action === "allow";
}
