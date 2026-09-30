use serde::{Deserialize, Serialize};
use std::env;
use std::time::Duration;

const BASE_URL: &str = "https://api.skanqrcode.com";

#[derive(Serialize)]
struct CheckRequest<'a> {
    target: &'a str,
}

#[derive(Debug, Deserialize)]
struct CheckResponse {
    verdict: String,
    action: String,
    mode: String,
    reasons: Vec<String>,
    cached: bool,
    #[serde(rename = "executionTimeMs")]
    execution_time_ms: u64,
    environment: String,
    #[serde(rename = "requestId")]
    request_id: String,
}

#[derive(Debug, Deserialize)]
struct ErrorBody {
    error: ErrorDetail,
}

#[derive(Debug, Deserialize)]
struct ErrorDetail {
    code: String,
    message: String,
    #[serde(rename = "requestId")]
    request_id: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let api_key = env::var("SKANQRCODE_API_KEY")
        .expect("SKANQRCODE_API_KEY is not set");

    let target = env::args()
        .nth(1)
        .unwrap_or_else(|| "https://example.com/login".to_string());

    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .build()?;

    let response = client
        .post(format!("{BASE_URL}/v1/check"))
        .bearer_auth(&api_key)
        .json(&CheckRequest { target: &target })
        .send()
        .await?;

    let status = response.status();
    let retry_after = response
        .headers()
        .get("retry-after")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let body = response.text().await?;

    if !status.is_success() {
        match serde_json::from_str::<ErrorBody>(&body) {
            Ok(err) => {
                eprintln!(
                    "{}: {} (http {status}, requestId={})",
                    err.error.code,
                    err.error.message,
                    err.error.request_id.unwrap_or_default()
                );
                match err.error.code.as_str() {
                    "rate_limited" => {
                        eprintln!("retry in {}s", retry_after.unwrap_or_else(|| "?".into()))
                    }
                    "quota_exceeded" => {
                        eprintln!("monthly quota exhausted; retrying won't help")
                    }
                    _ => {}
                }
            }
            // Not the documented JSON (e.g. an HTML 502 from a proxy).
            Err(_) => eprintln!("internal: http {status}: {body}"),
        }
        std::process::exit(1);
    }

    let result: CheckResponse = serde_json::from_str(&body)?;

    println!("verdict:         {}", result.verdict);
    println!("action:          {}", result.action);
    println!("mode:            {}", result.mode);
    println!("reasons:         {:?}", result.reasons);
    println!("cached:          {}", result.cached);
    println!("executionTimeMs: {}", result.execution_time_ms);
    println!("environment:     {}", result.environment);
    println!("requestId:       {}", result.request_id);

    match result.action.as_str() {
        "block" => println!("\nBLOCK: do not open this link."),
        "warn" => println!("\nWARN: proceed with caution."),
        _ => {}
    }
    if result.environment == "sandbox" {
        println!("(sandbox key: results are for integration testing only)");
    }

    Ok(())
}
