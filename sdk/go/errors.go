package skanqrcode

import "fmt"

// APIError represents the typed {error:{code,message,requestId}} shape
// returned by the API on any non-2xx response.
type APIError struct {
	Code       string
	Message    string
	RequestID  string
	StatusCode int
}

func (e *APIError) Error() string {
	return fmt.Sprintf("skanqrcode: %s (status=%d, requestId=%s): %s", e.Code, e.StatusCode, e.RequestID, e.Message)
}

type apiErrorBody struct {
	Error struct {
		Code      string `json:"code"`
		Message   string `json:"message"`
		RequestID string `json:"requestId"`
	} `json:"error"`
}
