use std::time::Duration;

use serde::Serialize;

use crate::error::{error_code, ApiErrorBody, Error};
use crate::models::{
    CheckResult, HealthResponse, HourlyUsageResponse, ListEntriesResponse, ListEntry, MatchType,
    PlanId, SessionUrlResponse, UsageResponse,
};

const DEFAULT_BASE_URL: &str = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(5);

#[derive(Serialize)]
struct CheckRequest<'a> {
    target: &'a str,
    #[serde(rename = "userId", skip_serializing_if = "Option::is_none")]
    user_id: Option<&'a str>,
}

#[derive(Serialize)]
struct AddEntryRequest<'a> {
    #[serde(rename = "matchType")]
    match_type: MatchType,
    value: &'a str,
}

#[derive(Serialize)]
struct CheckoutRequest<'a> {
    #[serde(rename = "planId")]
    plan_id: PlanId,
    #[serde(rename = "turnstileToken")]
    turnstile_token: &'a str,
}

pub struct Client {
    api_key: String,
    base_url: String,
    timeout: Duration,
    http: reqwest::Client,
}

impl Client {
    pub fn new(api_key: impl Into<String>) -> Self {
        Self {
            api_key: api_key.into(),
            base_url: DEFAULT_BASE_URL.to_string(),
            timeout: DEFAULT_TIMEOUT,
            http: reqwest::Client::new(),
        }
    }

    pub fn base_url(mut self, url: impl Into<String>) -> Self {
        self.base_url = url.into();
        self
    }

    pub fn timeout(mut self, d: Duration) -> Self {
        self.timeout = d;
        self
    }

    /// Classifies a URL or IP address. `user_id` is an opaque end-user identifier (1-128 chars)
    /// that enables per-user result caching. Branch on `result.action`.
    pub async fn check_url(
        &self,
        target: &str,
        user_id: Option<&str>,
    ) -> Result<CheckResult, Error> {
        let request = self
            .request(reqwest::Method::POST, "/v1/check")
            .json(&CheckRequest { target, user_id });
        self.send(request).await
    }

    /// Monthly quota summary. `month` is "YYYY-MM" (UTC); `None` means the current month.
    pub async fn get_usage(&self, month: Option<&str>) -> Result<UsageResponse, Error> {
        let request = self
            .request(reqwest::Method::GET, "/v1/usage")
            .query(&query(&[("month", month.map(str::to_string))]));
        self.send(request).await
    }

    /// Hour-by-hour usage and rate-limit utilization. `month` is "YYYY-MM" (UTC).
    pub async fn get_usage_hourly(
        &self,
        month: Option<&str>,
    ) -> Result<HourlyUsageResponse, Error> {
        let request = self
            .request(reqwest::Method::GET, "/v1/usage/hourly")
            .query(&query(&[("month", month.map(str::to_string))]));
        self.send(request).await
    }

    /// Pro and Business plans only.
    pub async fn list_allow_list(
        &self,
        limit: Option<u32>,
        cursor: Option<&str>,
    ) -> Result<ListEntriesResponse, Error> {
        self.list_entries("/v1/allow-list", limit, cursor).await
    }

    /// Needs an `admin`-scope key; Pro and Business plans only. Idempotent (200 or 201).
    pub async fn add_allow_list_entry(
        &self,
        match_type: MatchType,
        value: &str,
    ) -> Result<ListEntry, Error> {
        self.add_entry("/v1/allow-list", match_type, value).await
    }

    /// Needs an `admin`-scope key; Pro and Business plans only.
    pub async fn delete_allow_list_entry(&self, entry_id: &str) -> Result<(), Error> {
        self.delete_entry("/v1/allow-list", entry_id).await
    }

    pub async fn list_block_list(
        &self,
        limit: Option<u32>,
        cursor: Option<&str>,
    ) -> Result<ListEntriesResponse, Error> {
        self.list_entries("/v1/block-list", limit, cursor).await
    }

    /// Needs an `admin`-scope key. Idempotent (200 or 201).
    pub async fn add_block_list_entry(
        &self,
        match_type: MatchType,
        value: &str,
    ) -> Result<ListEntry, Error> {
        self.add_entry("/v1/block-list", match_type, value).await
    }

    /// Needs an `admin`-scope key.
    pub async fn delete_block_list_entry(&self, entry_id: &str) -> Result<(), Error> {
        self.delete_entry("/v1/block-list", entry_id).await
    }

    /// Human-in-the-loop, `admin` scope: hand the returned URL to a person, never complete
    /// checkout from an autonomous agent. Needs a Turnstile token from a browser flow.
    pub async fn create_checkout_session(
        &self,
        plan_id: PlanId,
        turnstile_token: &str,
    ) -> Result<SessionUrlResponse, Error> {
        let request = self
            .request(reqwest::Method::POST, "/v1/billing/checkout")
            .json(&CheckoutRequest {
                plan_id,
                turnstile_token,
            });
        self.send(request).await
    }

    /// Human-in-the-loop, `admin` scope: hand the returned billing-portal URL to a person.
    pub async fn create_portal_session(&self) -> Result<SessionUrlResponse, Error> {
        let request = self.request(reqwest::Method::POST, "/v1/billing/portal");
        self.send(request).await
    }

    /// Liveness only. Sends no Authorization header.
    pub async fn get_health(&self) -> Result<HealthResponse, Error> {
        let request = self
            .http
            .get(format!("{}/health", self.base_url))
            .timeout(self.timeout);
        self.send(request).await
    }

    async fn list_entries(
        &self,
        path: &str,
        limit: Option<u32>,
        cursor: Option<&str>,
    ) -> Result<ListEntriesResponse, Error> {
        let request = self.request(reqwest::Method::GET, path).query(&query(&[
            ("limit", limit.map(|l| l.to_string())),
            ("cursor", cursor.map(str::to_string)),
        ]));
        self.send(request).await
    }

    async fn add_entry(
        &self,
        path: &str,
        match_type: MatchType,
        value: &str,
    ) -> Result<ListEntry, Error> {
        let request = self
            .request(reqwest::Method::POST, path)
            .json(&AddEntryRequest { match_type, value });
        self.send(request).await
    }

    async fn delete_entry(&self, path: &str, entry_id: &str) -> Result<(), Error> {
        let request = self.request(
            reqwest::Method::DELETE,
            &format!("{path}/{}", percent_encode(entry_id)),
        );
        // 204 No Content: nothing to parse.
        self.read_success(request).await.map(|_| ())
    }

    fn request(&self, method: reqwest::Method, path: &str) -> reqwest::RequestBuilder {
        self.http
            .request(method, format!("{}{}", self.base_url, path))
            .bearer_auth(&self.api_key)
            .timeout(self.timeout)
    }

    async fn send<T>(&self, request: reqwest::RequestBuilder) -> Result<T, Error>
    where
        T: serde::de::DeserializeOwned,
    {
        let body = self.read_success(request).await?;
        Ok(serde_json::from_str(&body)?)
    }

    /// Sends the request and returns the body of a 2xx response, or the typed error.
    async fn read_success(&self, request: reqwest::RequestBuilder) -> Result<String, Error> {
        let response = request.send().await?;
        let status = response.status();
        let retry_after = response
            .headers()
            .get(reqwest::header::RETRY_AFTER)
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.trim().parse::<u64>().ok());
        let header_request_id = response
            .headers()
            .get("x-request-id")
            .and_then(|v| v.to_str().ok())
            .unwrap_or_default()
            .to_string();
        let body = response.text().await?;

        if status.is_success() {
            return Ok(body);
        }

        // A body that isn't the documented JSON (e.g. a proxy's HTML 502) keeps the synthetic
        // `internal` code and the HTTP status.
        Err(match serde_json::from_str::<ApiErrorBody>(&body) {
            Ok(err_body) => Error::Api {
                code: err_body.error.code,
                message: err_body.error.message,
                request_id: err_body.error.request_id.unwrap_or(header_request_id),
                status: status.as_u16(),
                retry_after,
            },
            Err(_) => Error::Api {
                code: error_code::INTERNAL.to_string(),
                message: body,
                request_id: header_request_id,
                status: status.as_u16(),
                retry_after,
            },
        })
    }
}

/// Drops the query parameters that weren't provided.
fn query(params: &[(&'static str, Option<String>)]) -> Vec<(&'static str, String)> {
    params
        .iter()
        .filter_map(|(key, value)| value.clone().map(|v| (*key, v)))
        .collect()
}

/// Percent-encodes everything but RFC 3986 unreserved characters, for use in a path segment.
fn percent_encode(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    for byte in input.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~' => {
                out.push(byte as char)
            }
            _ => out.push_str(&format!("%{byte:02X}")),
        }
    }
    out
}
