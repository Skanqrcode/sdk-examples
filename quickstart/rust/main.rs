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
    mode: String,
    score: u8,
    reasons: Vec<String>,
    cached: bool,
    partial: bool,
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
    request_id: String,
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
    let body = response.text().await?;

    if !status.is_success() {
        let err: ErrorBody = serde_json::from_str(&body)
            .unwrap_or_else(|_| panic!("http {status}: {body}"));
        eprintln!(
            "{}: {} (requestId={})",
            err.error.code, err.error.message, err.error.request_id
        );
        std::process::exit(1);
    }

    let result: CheckResponse = serde_json::from_str(&body)?;

    println!("verdict:    {}", result.verdict);
    println!("mode:       {}", result.mode);
    println!("score:      {}", result.score);
    println!("reasons:    {:?}", result.reasons);
    println!("cached:     {}", result.cached);
    println!("partial:    {}", result.partial);
    println!("requestId:  {}", result.request_id);

    match result.verdict.as_str() {
        "malicious" => println!("\nBLOCK: do not open this link."),
        "suspicious" => println!("\nWARN: proceed with caution."),
        _ => {}
    }

    Ok(())
}
