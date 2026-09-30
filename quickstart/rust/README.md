# SkanQRCode Rust quickstart

Raw usage of `POST /v1/check` with `reqwest` and `serde` — no SDK.

## Run

```sh
export SKANQRCODE_API_KEY=sk_test_...
cargo run -- "https://example.com/login"
```

If no argument is given, it checks `https://example.com/login`.

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
