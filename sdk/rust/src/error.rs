use serde::Deserialize;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("skanqrcode: {code} (status={status}, requestId={request_id}): {message}")]
    Api {
        code: String,
        message: String,
        request_id: String,
        status: u16,
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
    pub message: String,
    #[serde(rename = "requestId")]
    pub request_id: String,
}
