// Package skanqrcode is a client for the SkanQRCode URL/QR-code safety API.
// See https://github.com/skanqrcode/sdk-examples/blob/main/docs/api-contract.md
// for the full API contract.
package skanqrcode

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

const (
	defaultBaseURL = "https://api.skanqrcode.com"
	defaultTimeout = 5 * time.Second
)

// Client is a SkanQRCode API client.
type Client struct {
	apiKey     string
	baseURL    string
	httpClient *http.Client
}

// Option configures a Client.
type Option func(*Client)

// WithBaseURL overrides the default API base URL.
func WithBaseURL(baseURL string) Option {
	return func(c *Client) {
		c.baseURL = baseURL
	}
}

// WithTimeout sets the request timeout used by the client's default HTTP client.
// It has no effect if WithHTTPClient is also used.
func WithTimeout(d time.Duration) Option {
	return func(c *Client) {
		c.httpClient.Timeout = d
	}
}

// WithHTTPClient overrides the HTTP client used to make requests.
func WithHTTPClient(httpClient *http.Client) Option {
	return func(c *Client) {
		c.httpClient = httpClient
	}
}

// New creates a Client authenticated with apiKey.
func New(apiKey string, opts ...Option) *Client {
	c := &Client{
		apiKey:  apiKey,
		baseURL: defaultBaseURL,
		httpClient: &http.Client{
			Timeout: defaultTimeout,
		},
	}
	for _, opt := range opts {
		opt(c)
	}
	return c
}

// CheckURL classifies target (a URL or IP address) via POST /v1/check.
func (c *Client) CheckURL(ctx context.Context, target string) (*CheckResult, error) {
	body, err := json.Marshal(struct {
		Target string `json:"target"`
	}{Target: target})
	if err != nil {
		return nil, fmt.Errorf("skanqrcode: encode request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/check", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("skanqrcode: build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	var result CheckResult
	if err := c.do(req, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetUsage returns hourly usage/verdict aggregates for the calling tenant
// between from and to via GET /v1/usage.
func (c *Client) GetUsage(ctx context.Context, from, to time.Time) (*UsageResponse, error) {
	q := url.Values{}
	q.Set("from", from.UTC().Format(time.RFC3339))
	q.Set("to", to.UTC().Format(time.RFC3339))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/v1/usage?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("skanqrcode: build request: %w", err)
	}

	var result UsageResponse
	if err := c.do(req, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (c *Client) do(req *http.Request, out interface{}) error {
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("skanqrcode: request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("skanqrcode: read response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var errBody apiErrorBody
		if jsonErr := json.Unmarshal(respBody, &errBody); jsonErr != nil {
			return &APIError{
				Code:       "unknown",
				Message:    string(respBody),
				StatusCode: resp.StatusCode,
			}
		}
		return &APIError{
			Code:       errBody.Error.Code,
			Message:    errBody.Error.Message,
			RequestID:  errBody.Error.RequestID,
			StatusCode: resp.StatusCode,
		}
	}

	if err := json.Unmarshal(respBody, out); err != nil {
		return fmt.Errorf("skanqrcode: decode response: %w", err)
	}
	return nil
}
