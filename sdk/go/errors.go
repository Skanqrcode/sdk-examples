package skanqrcode

import (
	"fmt"
	"time"
)

// ErrorCode is the API's error.code. The set is closed today, but the type is a plain string
// so a code added later still decodes.
type ErrorCode string

const (
	ErrCodeInvalidRequest         ErrorCode = "invalid_request"
	ErrCodeUnauthorized           ErrorCode = "unauthorized"
	ErrCodeForbidden              ErrorCode = "forbidden"
	ErrCodeNotFound               ErrorCode = "not_found"
	ErrCodePlanFeatureUnavailable ErrorCode = "plan_feature_unavailable"
	ErrCodePaymentRequired        ErrorCode = "payment_required"
	ErrCodeRateLimited            ErrorCode = "rate_limited"
	ErrCodeQuotaExceeded          ErrorCode = "quota_exceeded"
	ErrCodeAuthUnavailable        ErrorCode = "auth_unavailable"
	ErrCodeInternal               ErrorCode = "internal"
)

// APIError represents the typed {error:{code,message,requestId}} shape
// returned by the API on any non-2xx response. If the body isn't that JSON
// (e.g. an HTML 502 from a proxy), Code is ErrCodeInternal.
type APIError struct {
	Code       ErrorCode
	Message    string
	RequestID  string
	StatusCode int
	// RetryAfter is the Retry-After header (429s); zero if the header is absent.
	RetryAfter time.Duration
}

func (e *APIError) Error() string {
	return fmt.Sprintf("skanqrcode: %s (status=%d, requestId=%s): %s", e.Code, e.StatusCode, e.RequestID, e.Message)
}

type apiErrorBody struct {
	Error struct {
		Code      ErrorCode `json:"code"`
		Message   string    `json:"message"`
		RequestID string    `json:"requestId"`
	} `json:"error"`
}
