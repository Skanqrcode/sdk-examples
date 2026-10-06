# skanqrcode

Rust SDK for the SkanQRCode URL/QR-code safety API.

## Install

Add to `Cargo.toml`:

```toml
[dependencies]
skanqrcode = "0.2"
tokio = { version = "1", features = ["rt-multi-thread", "macros"] }
```

Use an `sk_test_` key (free sandbox plan) while integrating; paid plans get an `sk_live_` key.

## Usage

```rust
use skanqrcode::{error_code, Action, Client, Error};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let client = Client::new(std::env::var("SKANQRCODE_API_KEY")?);

    // The second argument is an optional user id; it enables per-user result caching.
    let result = match client.check_url("https://example.com/login", Some("user-4821")).await {
        Ok(result) => result,
        Err(Error::Api { code, retry_after, request_id, message, .. }) => {
            if code == error_code::RATE_LIMITED {
                eprintln!("rate limited, retry in {retry_after:?}s (requestId={request_id})");
            } else {
                eprintln!("skanqrcode error {code}: {message} (requestId={request_id})");
            }
            return Ok(());
        }
        Err(err) => return Err(err.into()),
    };

    match result.action {
        Action::Block => println!("blocked: {:?}", result.reasons),
        Action::Warn => println!("warn user before proceeding: {:?}", result.reasons),
        Action::Allow => println!("safe to open"),
    }

    Ok(())
}
```

`CheckResult` has `verdict`, `action` (`Allow` / `Warn` / `Block`), `mode`, `reasons` (plain
strings), `final_url`, `cached`, `execution_time_ms`, `environment` (`Sandbox` / `Production`),
`licensed_for_production`, `request_id`, and `related` (IP mode only). Branch on `action`;
`should_block()` and `is_safe()` are shortcuts for block / allow, and warn is neither.
Sandbox results are for integration testing only.

## Usage and lists

```rust
use skanqrcode::MatchType;

let usage = client.get_usage(Some("2026-09")).await?; // None for the current month
println!("{} / {}", usage.total_requests, usage.monthly_quota);

let hourly = client.get_usage_hourly(Some("2026-09")).await?;
for h in &hourly.hours {
    println!("{} {} {}%", h.hour, h.total, h.capacity_used_percent);
}

// Block list (every plan); the allow list (Pro and Business) has the same methods.
let entry = client.add_block_list_entry(MatchType::Domain, "malicious-example.com").await?; // admin-scope key
let mut page = client.list_block_list(Some(100), None).await?;
while let Some(cursor) = page.next_cursor.clone() {
    page = client.list_block_list(Some(100), Some(&cursor)).await?;
}
client.delete_block_list_entry(&entry.id).await?;
```

Also available: `list_allow_list`, `add_allow_list_entry`, `delete_allow_list_entry`, and
`get_health()` (no key needed). `create_checkout_session(plan_id, turnstile_token)` and
`create_portal_session()` are human-in-the-loop, admin-scope calls: hand the returned URL to a
person rather than completing checkout from an agent.

## Error handling

Every non-2xx response is `Error::Api { code, message, request_id, status, retry_after }`.
`code` is a plain string, one of the `error_code` constants (`invalid_request`, `unauthorized`,
`forbidden`, `not_found`, `plan_feature_unavailable`, `payment_required`, `rate_limited`,
`quota_exceeded`, `auth_unavailable`, `internal`); a code added later still comes through as a
string. `retry_after` is the `Retry-After` header in seconds (`None` if absent). A non-JSON error
body (such as a proxy's HTML 502) is returned as code `internal` with the HTTP status. The SDK
doesn't retry: retry `rate_limited` after `retry_after`, `auth_unavailable` shortly and 5xx with
backoff, never `quota_exceeded` or 4xx. Fail closed if a check errors.

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
