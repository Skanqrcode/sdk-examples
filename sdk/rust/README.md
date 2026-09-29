# skanqrcode

Rust SDK for the SkanQRCode URL/QR-code safety API.

## Install

Add to `Cargo.toml`:

```toml
[dependencies]
skanqrcode = "0.1"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
```

## Usage

```rust
use skanqrcode::{Client, Error, Recommendation};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new(std::env::var("SKANQRCODE_API_KEY")?);

    let result = match client.check_url("https://example.com/login").await {
        Ok(result) => result,
        Err(Error::Api { code, message, request_id, .. }) => {
            eprintln!("skanqrcode error {code}: {message} (requestId={request_id})");
            return Ok(());
        }
        Err(err) => return Err(err.into()),
    };

    match result.recommendation() {
        Recommendation::Block => println!("blocked: {:?}", result.reasons),
        Recommendation::Warn => println!("warn user before proceeding: {:?}", result.reasons),
        Recommendation::Proceed => println!("safe to open"),
    }

    Ok(())
}
```

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
