package skanqrcode

// Verdict is the classification decision returned for a checked target.
type Verdict string

const (
	VerdictMalicious    Verdict = "malicious"
	VerdictSuspicious   Verdict = "suspicious"
	VerdictNotMalicious Verdict = "not_malicious"
)

// Action is what the caller should do with the target. It maps from Verdict the same way on
// every plan (not_malicious -> allow, suspicious -> warn, malicious -> block); branch on it.
type Action string

const (
	ActionAllow Action = "allow"
	ActionWarn  Action = "warn"
	ActionBlock Action = "block"
)

// Mode describes what kind of target was classified.
type Mode string

const (
	ModeURL Mode = "url"
	ModeIP  Mode = "ip"
)

// Environment is derived from the key's plan: sk_test_ keys are "sandbox".
type Environment string

const (
	EnvironmentSandbox    Environment = "sandbox"
	EnvironmentProduction Environment = "production"
)

// MatchType is what an allow-list or block-list entry matches.
type MatchType string

const (
	MatchTypeURL    MatchType = "url"
	MatchTypeHost   MatchType = "host"
	MatchTypeDomain MatchType = "domain"
	MatchTypeIP     MatchType = "ip"
)

// PlanID is a paid plan that can be bought through a checkout session.
type PlanID string

const (
	PlanPro      PlanID = "pro"
	PlanBusiness PlanID = "business"
)

// RelatedHost is a host recently associated with a checked IP address.
type RelatedHost struct {
	Host    string  `json:"host"`
	Verdict Verdict `json:"verdict"`
}

// CheckResult is the response of POST /v1/check.
type CheckResult struct {
	Verdict Verdict `json:"verdict"`
	Action  Action  `json:"action"`
	Mode    Mode    `json:"mode"`
	// Reasons are plain-string reason codes, so a new code doesn't break decoding.
	Reasons []string `json:"reasons"`
	// FinalURL is where a shortened link resolved to, or nil.
	FinalURL *string `json:"finalUrl"`
	Cached   bool    `json:"cached"`
	// ExecutionTimeMs >= 180 means the evaluation deadline was hit and the result is best-effort.
	ExecutionTimeMs       int         `json:"executionTimeMs"`
	Environment           Environment `json:"environment"`
	LicensedForProduction bool        `json:"licensedForProduction"`
	RequestID             string      `json:"requestId"`
	// Related is set in IP mode only: recently associated hosts, most recent first.
	Related []RelatedHost `json:"related,omitempty"`
}

// ShouldBlock reports whether the caller should refuse to open the target.
func (r *CheckResult) ShouldBlock() bool {
	return r.Action == ActionBlock
}

// IsSafe reports whether the target can be opened without warning the user.
// ActionWarn is neither safe nor blocked; surface it to the user.
func (r *CheckResult) IsSafe() bool {
	return r.Action == ActionAllow
}

// UsageResponse is the response of GET /v1/usage.
type UsageResponse struct {
	TenantID          string `json:"tenantId"`
	Month             string `json:"month"`
	MonthlyQuota      int    `json:"monthlyQuota"`
	TotalRequests     int    `json:"totalRequests"`
	AvailableRequests int    `json:"availableRequests"`
}

// UsageHour is a single (hour, mode) usage/verdict aggregate bucket.
type UsageHour struct {
	Hour                string  `json:"hour"`
	Mode                Mode    `json:"mode"`
	Total               int     `json:"total"`
	CapacityUsedPercent float64 `json:"capacityUsedPercent"`
	BlockedRpm          int     `json:"blockedRpm"`
	BlockedQuota        int     `json:"blockedQuota"`
	Malicious           int     `json:"malicious"`
	Suspicious          int     `json:"suspicious"`
	NotMalicious        int     `json:"notMalicious"`
	Cached              int     `json:"cached"`
}

// HourlyUsageResponse is the response of GET /v1/usage/hourly.
type HourlyUsageResponse struct {
	TenantID string `json:"tenantId"`
	Month    string `json:"month"`
	RpmLimit int    `json:"rpmLimit"`
	// HourlyCapacity is RpmLimit*60, a reading aid only: limits are enforced per minute.
	HourlyCapacity int         `json:"hourlyCapacity"`
	Hours          []UsageHour `json:"hours"`
}

// ListEntry is an allow-list or block-list entry.
type ListEntry struct {
	ID        string    `json:"id"`
	MatchType MatchType `json:"matchType"`
	Value     string    `json:"value"`
	CreatedAt string    `json:"createdAt"`
}

// ListEntriesResponse is one page of an allow list or block list, newest first.
type ListEntriesResponse struct {
	Entries []ListEntry `json:"entries"`
	// NextCursor is nil on the last page.
	NextCursor *string `json:"nextCursor"`
}

// SessionURLResponse carries a checkout or billing-portal URL to hand to a person.
type SessionURLResponse struct {
	URL string `json:"url"`
}

// HealthResponse is the response of GET /health.
type HealthResponse struct {
	Status string `json:"status"`
}
