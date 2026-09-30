export type Verdict = "malicious" | "suspicious" | "not_malicious";
/** Fixed mapping: not_malicious->allow, suspicious->warn, malicious->block. */
export type Action = "allow" | "warn" | "block";
export type Mode = "url" | "ip";
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

export const ERROR_CODES: readonly ErrorCode[];

export interface RelatedHost {
  host: string;
  verdict: Verdict;
}

export interface CheckResult {
  verdict: Verdict;
  action: Action;
  mode: Mode;
  reasons: string[];
  finalUrl: string | null;
  cached: boolean;
  /** >= 180 means the deadline was hit and the result is best-effort. */
  executionTimeMs: number;
  environment: Environment;
  licensedForProduction: boolean;
  requestId: string;
  /** IP mode only. */
  related?: RelatedHost[];
}

export interface UsageResponse {
  tenantId: string;
  month: string;
  monthlyQuota: number;
  totalRequests: number;
  availableRequests: number;
}

export interface UsageHour {
  hour: string;
  mode: Mode;
  total: number;
  capacityUsedPercent: number;
  blockedRpm: number;
  blockedQuota: number;
  malicious: number;
  suspicious: number;
  notMalicious: number;
  cached: number;
}

export interface UsageHourlyResponse {
  tenantId: string;
  month: string;
  rpmLimit: number;
  hourlyCapacity: number;
  hours: UsageHour[];
}

export interface ListEntry {
  id: string;
  matchType: MatchType;
  value: string;
  createdAt: string;
}

export interface ListPage {
  entries: ListEntry[];
  nextCursor: string | null;
}

export interface SessionResponse {
  url: string;
}

export interface HealthResponse {
  status: "ok";
}

export interface SkanQRCodeClientOptions {
  apiKey: string;
  baseUrl?: string;
  timeoutMs?: number;
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
    retryAfter?: number | null,
  );
}

export class SkanQRCodeClient {
  constructor(options: SkanQRCodeClientOptions);
  checkUrl(target: string, userId?: string): Promise<CheckResult>;
  getUsage(month?: string): Promise<UsageResponse>;
  getUsageHourly(month?: string): Promise<UsageHourlyResponse>;
  listAllowList(limit?: number, cursor?: string): Promise<ListPage>;
  addAllowListEntry(matchType: MatchType, value: string): Promise<ListEntry>;
  deleteAllowListEntry(entryId: string): Promise<void>;
  listBlockList(limit?: number, cursor?: string): Promise<ListPage>;
  addBlockListEntry(matchType: MatchType, value: string): Promise<ListEntry>;
  deleteBlockListEntry(entryId: string): Promise<void>;
  /** Human-in-the-loop, admin scope: hand the returned URL to a person. */
  createCheckoutSession(planId: PlanId, turnstileToken: string): Promise<SessionResponse>;
  /** Human-in-the-loop, admin scope: hand the returned URL to a person. */
  createPortalSession(): Promise<SessionResponse>;
  getHealth(): Promise<HealthResponse>;
}

/** True only when `action === "block"`. */
export function shouldBlock(result: CheckResult): boolean;
/** True only when `action === "allow"`; `warn` is neither. */
export function isSafe(result: CheckResult): boolean;
