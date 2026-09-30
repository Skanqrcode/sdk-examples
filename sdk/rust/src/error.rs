use serde::Deserialize;

/// Known values of `error.code`. The set is closed today, but `Error::Api::code` is a plain
/// `String` so a code added later still deserializes.
pub mod error_code {
    pub const INVALID_REQUEST: &str = "invalid_request";
    pub const UNAUTHORIZED: &str = "unauthorized";
    pub const FORBIDDEN: &str = "forbidden";
    pub const NOT_FOUND: &str = "not_found";
    pub const PLAN_FEATURE_UNAVAILABLE: &str = "plan_feature_unavailable";
    pub const PAYMENT_REQUIRED: &str = "payment_required";
    pub const RATE_LIMITED: &str = "rate_limited";
    pub const QUOTA_EXCEEDED: &str = "quota_exceeded";
    pub const AUTH_UNAVAILABLE: &str = "auth_unavailable";
    pub const INTERNAL: &str = "internal";
}

#[derive(Debug, thiserror::Error)]
pub enum Error {
    /// Any non-2xx response. `retry_after` is the `Retry-After` header in seconds (429s).
    /// If the body wasn't the documented JSON (e.g. an HTML 502 from a proxy), `code` is
    /// `"internal"` and `request_id` comes from `X-Request-Id`, or is empty.
    #[error("skanqrcode: {code} (status={status}, requestId={request_id}): {message}")]
    Api {
        code: String,
        message: String,
        request_id: String,
        status: u16,
        retry_after: Option<u64>,
    },

    #[error("skanqrcode: request failed: {0}")]
    Request(#[from] reqwest::Error),

    #[error("skanqrcode: failed to decode response: {0}")]
    Decode(#[from] serde_json::Error),
}

#[derive(Debug, Deserialize)]
pub(crate) struct ApiErrorBody {
    pub error: ApiErrorDetail,
}

#[derive(Debug, Deserialize)]
pub(crate) struct ApiErrorDetail {
    pub code: String,
    #[serde(default)]
    pub message: String,
    #[serde(rename = "requestId", default)]
    pub request_id: Option<String>,
}
