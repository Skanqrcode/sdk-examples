# SkanQRCode TypeScript quickstart

Raw `fetch` call to `POST /v1/check` — no SDK, just the contract. See
[../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.

## Run

```bash
npm install
export SKANQRCODE_API_KEY=lure_test_...
npm start -- "https://example.com/login"
```

Requires the `SKANQRCODE_API_KEY` environment variable.
