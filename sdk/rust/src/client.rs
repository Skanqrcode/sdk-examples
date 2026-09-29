use std::time::Duration;

use serde::Serialize;

use crate::error::{ApiErrorBody, Error};
use crate::models::{CheckResult, UsageResponse};

const DEFAULT_BASE_URL: &str = "https://api.skanqrcode.com";
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(5);

#[derive(Serialize)]
struct CheckRequest<'a> {
    target: &'a str,
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

    pub async fn check_url(&self, target: &str) -> Result<CheckResult, Error> {
        let response = self
            .http
            .post(format!("{}/v1/check", self.base_url))
            .bearer_auth(&self.api_key)
            .timeout(self.timeout)
            .json(&CheckRequest { target })
            .send()
            .await?;

        self.handle_response(response).await
    }

    pub async fn get_usage(&self, from: &str, to: &str) -> Result<UsageResponse, Error> {
        let response = self
            .http
            .get(format!("{}/v1/usage", self.base_url))
            .bearer_auth(&self.api_key)
            .timeout(self.timeout)
            .query(&[("from", from), ("to", to)])
            .send()
            .await?;

        self.handle_response(response).await
    }

    async fn handle_response<T>(&self, response: reqwest::Response) -> Result<T, Error>
    where
        T: serde::de::DeserializeOwned,
    {
        let status = response.status();
        let body = response.text().await?;

        if !status.is_success() {
            return match serde_json::from_str::<ApiErrorBody>(&body) {
                Ok(err_body) => Err(Error::Api {
                    code: err_body.error.code,
                    message: err_body.error.message,
                    request_id: err_body.error.request_id,
                    status: status.as_u16(),
                }),
                Err(_) => Err(Error::Api {
                    code: "unknown".to_string(),
                    message: body,
                    request_id: String::new(),
                    status: status.as_u16(),
                }),
            };
        }

        Ok(serde_json::from_str(&body)?)
    }
}
