/**
 * Minimal, dependency-free example of calling POST /v1/check with raw fetch.
 * See ../../docs/api-contract.md for the full contract.
 */

const BASE_URL = "https://api.skanqrcode.com";

type Verdict = "malicious" | "suspicious" | "not_malicious";
type Action = "allow" | "warn" | "block";
type Mode = "url" | "ip";

interface CheckResult {
  verdict: Verdict;
  action: Action;
  mode: Mode;
  reasons: string[];
  finalUrl: string | null;
  cached: boolean;
  executionTimeMs: number;
  environment: "sandbox" | "production";
  licensedForProduction: boolean;
  requestId: string;
}

interface ApiError {
  error: {
    code: string;
    message: string;
    requestId: string;
  };
}

async function checkUrl(target: string, apiKey: string): Promise<CheckResult> {
  const response = await fetch(`${BASE_URL}/v1/check`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({ target }),
    signal: AbortSignal.timeout(5000),
  });

  if (!response.ok) {
    // The body may not be the documented JSON (e.g. a proxy's HTML 502) — don't crash on it.
    const body = (await response.json().catch(() => undefined)) as ApiError | undefined;
    const code = body?.error.code ?? "internal";
    let message = `SkanQRCode error ${response.status} (${code}): ${body?.error.message ?? "unexpected response"}`;
    if (body) message += ` [requestId=${body.error.requestId}]`;
    // rate_limited: retry after Retry-After seconds. quota_exceeded: don't retry.
    const retryAfter = response.headers.get("Retry-After");
    if (code === "rate_limited" && retryAfter) message += ` (retry in ${retryAfter}s)`;
    throw new Error(message);
  }

  return (await response.json()) as CheckResult;
}

async function main() {
  const apiKey = process.env.SKANQRCODE_API_KEY;
  if (!apiKey) {
    console.error("Missing SKANQRCODE_API_KEY environment variable.");
    process.exit(1);
  }

  const target = process.argv[2] ?? "https://example.com/login";
  const result = await checkUrl(target, apiKey);

  console.log(`target:     ${target}`);
  console.log(`verdict:    ${result.verdict}`);
  console.log(`mode:       ${result.mode}`);
  console.log(`action:     ${result.action}`);
  console.log(`reasons:    ${result.reasons.join(", ") || "(none)"}`);
  console.log(`cached:     ${result.cached}`);
  console.log(`time:       ${result.executionTimeMs} ms`);
  console.log(`env:        ${result.environment}`);
  console.log(`requestId:  ${result.requestId}`);

  // Branch on `action`: allow -> proceed, warn -> tell the user, block -> stop.
  // See docs/api-contract.md "Suggested client behavior".
  if (result.action === "block") {
    console.log("\nDecision: BLOCK");
  } else if (result.action === "warn") {
    console.log("\nDecision: WARN");
  } else {
    console.log("\nDecision: PROCEED");
  }

  if (!result.licensedForProduction) {
    console.log("Note: sandbox key — integration testing only, don't enforce on this in production.");
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
