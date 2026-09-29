// Minimal, dependency-free example of calling POST /v1/check with raw fetch.
// See ../../docs/api-contract.md for the full contract. Requires Node 18+ (global fetch).

const BASE_URL = "https://api.skanqrcode.com";

async function checkUrl(target, apiKey) {
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
    const body = await response.json();
    throw new Error(
      `SkanQRCode error ${response.status} (${body.error.code}): ${body.error.message} [requestId=${body.error.requestId}]`,
    );
  }

  return response.json();
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
  console.log(`score:      ${result.score}`);
  console.log(`reasons:    ${result.reasons.join(", ") || "(none)"}`);
  console.log(`cached:     ${result.cached}`);
  console.log(`partial:    ${result.partial}`);
  console.log(`requestId:  ${result.requestId}`);

  // Not malicious -> safe to proceed. Suspicious -> warn but don't hard-block.
  // Malicious -> block. See docs/api-contract.md "Suggested client behavior".
  if (result.verdict === "malicious") {
    console.log("\nDecision: BLOCK");
  } else if (result.verdict === "suspicious") {
    console.log("\nDecision: WARN");
  } else {
    console.log("\nDecision: PROCEED");
  }
}

main().catch((err) => {
  console.error(err.message ?? err);
  process.exit(1);
});
