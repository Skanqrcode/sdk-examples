# @skanqrcode/sdk

Typed TypeScript/JavaScript client for the SkanQRCode API. No runtime dependencies — uses
global `fetch`. See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API
contract.

## Install

```bash
npm install @skanqrcode/sdk
```

## Usage

```ts
import { SkanQRCodeClient, shouldBlock } from "@skanqrcode/sdk";

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY! });

const result = await client.checkUrl("https://example.com/login");

if (shouldBlock(result)) {
  console.log("Blocked:", result.reasons.join(", "));
} else if (result.verdict === "suspicious") {
  console.log("Proceed with caution:", result.reasons.join(", "));
} else {
  console.log("Safe to open.");
}
```

## Error handling

Non-2xx responses throw `SkanQRCodeError`, which carries the typed error fields from the API:

```ts
import { SkanQRCodeClient, SkanQRCodeError } from "@skanqrcode/sdk";

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY! });

try {
  await client.checkUrl("https://example.com");
} catch (err) {
  if (err instanceof SkanQRCodeError) {
    console.error(err.status, err.code, err.message, err.requestId);
  } else {
    throw err;
  }
}
```
