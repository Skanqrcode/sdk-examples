use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Verdict {
    Malicious,
    Suspicious,
    #[serde(rename = "not_malicious")]
    NotMalicious,
}

/// What the caller should do. Branch on this rather than on `Verdict`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Action {
    Allow,
    Warn,
    Block,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Url,
    Ip,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Environment {
    Sandbox,
    Production,
}

/// What an allow-list or block-list entry matches.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MatchType {
    Url,
    Host,
    Domain,
    Ip,
}

/// A paid plan that can be bought through a checkout session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PlanId {
    Pro,
    Business,
}

#[derive(Debug, Clone, Deserialize)]
pub struct RelatedHost {
    pub host: String,
    pub verdict: Verdict,
}

#[derive(Debug, Clone, Deserialize)]
pub struct CheckResult {
    pub verdict: Verdict,
    pub action: Action,
    pub mode: Mode,
    /// Reason codes are plain strings so a new code doesn't break deserialization.
    pub reasons: Vec<String>,
    #[serde(rename = "finalUrl")]
    pub final_url: Option<String>,
    pub cached: bool,
    /// Server-side evaluation time in milliseconds.
    #[serde(rename = "executionTimeMs")]
    pub execution_time_ms: u64,
    pub environment: Environment,
    #[serde(rename = "licensedForProduction")]
    pub licensed_for_production: bool,
    #[serde(rename = "requestId")]
    pub request_id: String,
    /// IP mode only: recently associated hosts, most recent first.
    #[serde(default)]
    pub related: Option<Vec<RelatedHost>>,
}

impl CheckResult {
    pub fn should_block(&self) -> bool {
        self.action == Action::Block
    }

    /// `Action::Warn` is neither safe nor blocked; surface it to the user.
    pub fn is_safe(&self) -> bool {
        self.action == Action::Allow
    }
}

#[derive(Debug, Clone, Deserialize)]
pub struct UsageResponse {
    #[serde(rename = "tenantId")]
    pub tenant_id: String,
    pub month: String,
    #[serde(rename = "monthlyQuota")]
    pub monthly_quota: u64,
    #[serde(rename = "totalRequests")]
    pub total_requests: u64,
    #[serde(rename = "availableRequests")]
    pub available_requests: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct UsageHour {
    pub hour: String,
    pub mode: Mode,
    pub total: u64,
    #[serde(rename = "capacityUsedPercent")]
    pub capacity_used_percent: f64,
    #[serde(rename = "blockedRpm")]
    pub blocked_rpm: u64,
    #[serde(rename = "blockedQuota")]
    pub blocked_quota: u64,
    pub malicious: u64,
    pub suspicious: u64,
    #[serde(rename = "notMalicious")]
    pub not_malicious: u64,
    pub cached: u64,
}

#[derive(Debug, Clone, Deserialize)]
pub struct HourlyUsageResponse {
    #[serde(rename = "tenantId")]
    pub tenant_id: String,
    pub month: String,
    #[serde(rename = "rpmLimit")]
    pub rpm_limit: u64,
    /// `rpm_limit * 60`; a reading aid only, limits are enforced per minute.
    #[serde(rename = "hourlyCapacity")]
    pub hourly_capacity: u64,
    pub hours: Vec<UsageHour>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ListEntry {
    pub id: String,
    #[serde(rename = "matchType")]
    pub match_type: MatchType,
    pub value: String,
    #[serde(rename = "createdAt")]
    pub created_at: String,
}

/// One page of an allow list or block list, newest first.
#[derive(Debug, Clone, Deserialize)]
pub struct ListEntriesResponse {
    pub entries: Vec<ListEntry>,
    /// `None` on the last page; pass it back as `cursor` to fetch the next one.
    #[serde(rename = "nextCursor")]
    pub next_cursor: Option<String>,
}

/// A checkout or billing-portal URL to hand to a person.
#[derive(Debug, Clone, Deserialize)]
pub struct SessionUrlResponse {
    pub url: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct HealthResponse {
    pub status: String,
}
