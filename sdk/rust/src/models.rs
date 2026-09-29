use serde::Deserialize;

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    Malicious,
    Suspicious,
    #[serde(rename = "not_malicious")]
    NotMalicious,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Url,
    Ip,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CheckResult {
    pub verdict: Verdict,
    pub mode: Mode,
    pub score: u8,
    pub reasons: Vec<String>,
    pub cached: bool,
    pub partial: bool,
    #[serde(rename = "requestId")]
    pub request_id: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Recommendation {
    Proceed,
    Warn,
    Block,
}

impl CheckResult {
    pub fn recommendation(&self) -> Recommendation {
        match self.verdict {
            Verdict::Malicious => Recommendation::Block,
            Verdict::Suspicious => Recommendation::Warn,
            Verdict::NotMalicious => Recommendation::Proceed,
        }
    }

    pub fn should_block(&self) -> bool {
        self.recommendation() == Recommendation::Block
    }

    pub fn is_safe(&self) -> bool {
        self.recommendation() == Recommendation::Proceed
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct UsageHour {
    pub hour: String,
    pub mode: Mode,
    pub total: u64,
    pub malicious: u64,
    pub suspicious: u64,
    #[serde(rename = "notMalicious")]
    pub not_malicious: u64,
    pub cached: u64,
    pub partial: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UsageResponse {
    #[serde(rename = "tenantId")]
    pub tenant_id: String,
    pub from: String,
    pub to: String,
    pub hours: Vec<UsageHour>,
}
