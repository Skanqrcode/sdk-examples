# SkanQRCode JavaScript quickstart

Raw `fetch` call to `POST /v1/check` — plain Node.js, no build step, no SDK. See
[../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.

## Run

```bash
npm install
export SKANQRCODE_API_KEY=lure_test_...
npm start -- "https://example.com/login"
```

Requires Node 18+ (for global `fetch`) and the `SKANQRCODE_API_KEY` environment variable.
