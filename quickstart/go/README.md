# SkanQRCode Go quickstart

Raw usage of `POST /v1/check` using only the Go standard library — no SDK, no dependencies.

## Run

```sh
export SKANQRCODE_API_KEY=lure_test_...
go run main.go "https://example.com/login"
```

If no argument is given, it checks `https://example.com/login`.

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
