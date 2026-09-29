package skanqrcode

// Verdict is the classification decision returned for a checked target.
type Verdict string

const (
	VerdictMalicious    Verdict = "malicious"
	VerdictSuspicious   Verdict = "suspicious"
	VerdictNotMalicious Verdict = "not_malicious"
)

// Mode describes what kind of target was classified.
type Mode string

const (
	ModeURL Mode = "url"
	ModeIP  Mode = "ip"
)

// Recommendation is a convenience allow/warn/block decision derived from Verdict,
// for callers that don't want to switch on the raw enum themselves.
type Recommendation string

const (
	RecommendationProceed Recommendation = "proceed"
	RecommendationWarn    Recommendation = "warn"
	RecommendationBlock   Recommendation = "block"
)

// CheckResult is the response of POST /v1/check.
type CheckResult struct {
	Verdict   Verdict  `json:"verdict"`
	Mode      Mode     `json:"mode"`
	Score     int      `json:"score"`
	Reasons   []string `json:"reasons"`
	Cached    bool     `json:"cached"`
	Partial   bool     `json:"partial"`
	RequestID string   `json:"requestId"`
}

// Recommendation maps the raw Verdict onto an allow/warn/block decision.
func (r *CheckResult) Recommendation() Recommendation {
	switch r.Verdict {
	case VerdictMalicious:
		return RecommendationBlock
	case VerdictSuspicious:
		return RecommendationWarn
	default:
		return RecommendationProceed
	}
}

// ShouldBlock reports whether the caller should refuse to open the target.
func (r *CheckResult) ShouldBlock() bool {
	return r.Recommendation() == RecommendationBlock
}

// IsSafe reports whether the target can be opened without warning the user.
func (r *CheckResult) IsSafe() bool {
	return r.Recommendation() == RecommendationProceed
}

// UsageHour is a single (hour, mode) usage/verdict aggregate bucket.
type UsageHour struct {
	Hour         string `json:"hour"`
	Mode         Mode   `json:"mode"`
	Total        int    `json:"total"`
	Malicious    int    `json:"malicious"`
	Suspicious   int    `json:"suspicious"`
	NotMalicious int    `json:"notMalicious"`
	Cached       int    `json:"cached"`
	Partial      int    `json:"partial"`
}

// UsageResponse is the response of GET /v1/usage.
type UsageResponse struct {
	TenantID string      `json:"tenantId"`
	From     string      `json:"from"`
	To       string      `json:"to"`
	Hours    []UsageHour `json:"hours"`
}
