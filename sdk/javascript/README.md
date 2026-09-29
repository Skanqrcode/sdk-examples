# skanqrcode

Plain-JS client for the SkanQRCode API — CommonJS and ESM, no build step, no runtime
dependencies (uses global `fetch`). See
[../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.

## Install

```bash
npm install skanqrcode
```

## Usage

```js
const { SkanQRCodeClient, shouldBlock } = require("skanqrcode");
// or: import { SkanQRCodeClient, shouldBlock } from "skanqrcode";

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

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

```js
const { SkanQRCodeClient, SkanQRCodeError } = require("skanqrcode");

const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

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
