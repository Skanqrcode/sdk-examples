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

export interface SkanQRCodeClientOptions {
  apiKey: string;
  baseUrl?: string;
  timeoutMs?: number;
}

export class SkanQRCodeError extends Error {
  readonly code: string;
  readonly requestId: string;
  readonly status: number;
  constructor(code: string, message: string, requestId: string, status: number);
}

export class SkanQRCodeClient {
  constructor(options: SkanQRCodeClientOptions);
  checkUrl(target: string): Promise<CheckResult>;
  getUsage(from: string, to: string): Promise<UsageResponse>;
}

export function shouldBlock(result: CheckResult): boolean;
export function isSafe(result: CheckResult): boolean;
