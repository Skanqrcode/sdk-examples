# SkanQRCode quickstart (Python)

Minimal, dependency-free example of calling `POST /v1/check` using only the
standard library (`urllib.request`, `json`).

## Run

```
export SKANQRCODE_API_KEY=sk_test_...
python3 quickstart.py "https://example.com/login"
```

See [`../../docs/api-contract.md`](../../docs/api-contract.md) for the full
request/response contract.
