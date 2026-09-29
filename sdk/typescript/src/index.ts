/**
 * @skanqrcode/sdk — typed client for the SkanQRCode API.
 * Contract: ../../../docs/api-contract.md
 */

export type Verdict = "malicious" | "suspicious" | "not_malicious";
export type Mode = "url" | "ip";

export interface CheckResult {
  verdict: Verdict;
  mode: Mode;
  score: number;
  reasons: string[];
  cached: boolean;
  partial: boolean;
  requestId: string;
}

export interface UsageHour {
  /** RFC3339 timestamp marking the start of the hour this bucket covers. */
  hour: string;
  mode: Mode;
  total: number;
  malicious: number;
  suspicious: number;
  notMalicious: number;
  cached: number;
  partial: number;
}

export interface UsageResponse {
  tenantId: string;
  from: string;
  to: string;
  hours: UsageHour[];
}

interface ApiErrorBody {
  error: {
    code: string;
    message: string;
    requestId: string;
  };
}

export class SkanQRCodeError extends Error {
  readonly code: string;
  readonly requestId: string;
  readonly status: number;

  constructor(code: string, message: string, requestId: string, status: number) {
    super(message);
    this.name = "SkanQRCodeError";
    this.code = code;
    this.requestId = requestId;
    this.status = status;
  }
}

export interface SkanQRCodeClientOptions {
  apiKey: string;
  baseUrl?: string;
  timeoutMs?: number;
}

const DEFAULT_BASE_URL = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT_MS = 5000;

export class SkanQRCodeClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly timeoutMs: number;

  constructor(options: SkanQRCodeClientOptions) {
    this.apiKey = options.apiKey;
    this.baseUrl = options.baseUrl ?? DEFAULT_BASE_URL;
    this.timeoutMs = options.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  }

  async checkUrl(target: string): Promise<CheckResult> {
    return this.request<CheckResult>("/v1/check", {
      method: "POST",
      body: JSON.stringify({ target }),
    });
  }

  async getUsage(from: string, to: string): Promise<UsageResponse> {
    const params = new URLSearchParams({ from, to });
    return this.request<UsageResponse>(`/v1/usage?${params.toString()}`, {
      method: "GET",
    });
  }

  private async request<T>(path: string, init: RequestInit): Promise<T> {
    const response = await fetch(`${this.baseUrl}${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${this.apiKey}`,
      },
      signal: AbortSignal.timeout(this.timeoutMs),
    });

    if (!response.ok) {
      const body = (await response.json()) as ApiErrorBody;
      throw new SkanQRCodeError(
        body.error.code,
        body.error.message,
        body.error.requestId,
        response.status,
      );
    }

    return (await response.json()) as T;
  }
}

/** not_malicious -> safe, suspicious -> warn, malicious -> block. */
export function shouldBlock(result: CheckResult): boolean {
  return result.verdict === "malicious";
}

/** True only for not_malicious; suspicious is a warn, not a pass. */
export function isSafe(result: CheckResult): boolean {
  return result.verdict === "not_malicious";
}
