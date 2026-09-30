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
	"strconv"
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

// CheckOption configures a single CheckURL call.
type CheckOption func(*checkRequest)

// WithUserID sends an opaque end-user identifier (1-128 chars), which enables per-user
// result caching. It is hashed server-side and never stored in clear.
func WithUserID(userID string) CheckOption {
	return func(r *checkRequest) {
		r.UserID = userID
	}
}

type checkRequest struct {
	Target string `json:"target"`
	UserID string `json:"userId,omitempty"`
}

// CheckURL classifies target (a URL or IP address) via POST /v1/check.
// Branch on result.Action.
func (c *Client) CheckURL(ctx context.Context, target string, opts ...CheckOption) (*CheckResult, error) {
	payload := checkRequest{Target: target}
	for _, opt := range opts {
		opt(&payload)
	}

	var result CheckResult
	if err := c.doJSON(ctx, http.MethodPost, "/v1/check", nil, payload, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetUsage returns the monthly quota summary via GET /v1/usage. month is "YYYY-MM" (UTC);
// pass "" for the current month.
func (c *Client) GetUsage(ctx context.Context, month string) (*UsageResponse, error) {
	var result UsageResponse
	if err := c.doJSON(ctx, http.MethodGet, "/v1/usage", monthQuery(month), nil, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetUsageHourly returns hour-by-hour usage and rate-limit utilization via
// GET /v1/usage/hourly. month is "YYYY-MM" (UTC); pass "" for the current month.
func (c *Client) GetUsageHourly(ctx context.Context, month string) (*HourlyUsageResponse, error) {
	var result HourlyUsageResponse
	if err := c.doJSON(ctx, http.MethodGet, "/v1/usage/hourly", monthQuery(month), nil, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// ListOptions pages through an allow list or block list. Zero values are omitted.
type ListOptions struct {
	// Limit is 1-500 (server default 100).
	Limit int
	// Cursor is the previous page's NextCursor.
	Cursor string
}

// ListAllowList returns one page of the allow list, newest first. Pro and Business plans only.
func (c *Client) ListAllowList(ctx context.Context, opts *ListOptions) (*ListEntriesResponse, error) {
	return c.listEntries(ctx, "/v1/allow-list", opts)
}

// AddAllowListEntry adds an entry to the allow list. Needs an admin-scope key; Pro and
// Business plans only. Adding is idempotent: both 200 and 201 are success.
func (c *Client) AddAllowListEntry(ctx context.Context, matchType MatchType, value string) (*ListEntry, error) {
	return c.addEntry(ctx, "/v1/allow-list", matchType, value)
}

// DeleteAllowListEntry removes an allow-list entry. Needs an admin-scope key; Pro and
// Business plans only.
func (c *Client) DeleteAllowListEntry(ctx context.Context, entryID string) error {
	return c.doJSON(ctx, http.MethodDelete, "/v1/allow-list/"+url.PathEscape(entryID), nil, nil, nil)
}

// ListBlockList returns one page of the block list, newest first.
func (c *Client) ListBlockList(ctx context.Context, opts *ListOptions) (*ListEntriesResponse, error) {
	return c.listEntries(ctx, "/v1/block-list", opts)
}

// AddBlockListEntry adds an entry to the block list. Needs an admin-scope key. Adding is
// idempotent: both 200 and 201 are success.
func (c *Client) AddBlockListEntry(ctx context.Context, matchType MatchType, value string) (*ListEntry, error) {
	return c.addEntry(ctx, "/v1/block-list", matchType, value)
}

// DeleteBlockListEntry removes a block-list entry. Needs an admin-scope key.
func (c *Client) DeleteBlockListEntry(ctx context.Context, entryID string) error {
	return c.doJSON(ctx, http.MethodDelete, "/v1/block-list/"+url.PathEscape(entryID), nil, nil, nil)
}

// CreateCheckoutSession starts a subscription checkout via POST /v1/billing/checkout.
// Human-in-the-loop: needs an admin-scope key and a Turnstile token from a browser flow; hand
// the returned URL to a person, never complete checkout from an autonomous agent.
func (c *Client) CreateCheckoutSession(ctx context.Context, planID PlanID, turnstileToken string) (*SessionURLResponse, error) {
	payload := struct {
		PlanID         PlanID `json:"planId"`
		TurnstileToken string `json:"turnstileToken"`
	}{planID, turnstileToken}

	var result SessionURLResponse
	if err := c.doJSON(ctx, http.MethodPost, "/v1/billing/checkout", nil, payload, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// CreatePortalSession opens the billing portal via POST /v1/billing/portal.
// Human-in-the-loop: needs an admin-scope key; hand the returned URL to a person.
func (c *Client) CreatePortalSession(ctx context.Context) (*SessionURLResponse, error) {
	var result SessionURLResponse
	if err := c.doJSON(ctx, http.MethodPost, "/v1/billing/portal", nil, nil, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetHealth is a liveness check via GET /health. It sends no Authorization header.
func (c *Client) GetHealth(ctx context.Context) (*HealthResponse, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/health", nil)
	if err != nil {
		return nil, fmt.Errorf("skanqrcode: build request: %w", err)
	}

	var result HealthResponse
	if err := c.do(req, false, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func monthQuery(month string) url.Values {
	q := url.Values{}
	if month != "" {
		q.Set("month", month)
	}
	return q
}

func (c *Client) listEntries(ctx context.Context, path string, opts *ListOptions) (*ListEntriesResponse, error) {
	q := url.Values{}
	if opts != nil {
		if opts.Limit > 0 {
			q.Set("limit", strconv.Itoa(opts.Limit))
		}
		if opts.Cursor != "" {
			q.Set("cursor", opts.Cursor)
		}
	}

	var result ListEntriesResponse
	if err := c.doJSON(ctx, http.MethodGet, path, q, nil, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

func (c *Client) addEntry(ctx context.Context, path string, matchType MatchType, value string) (*ListEntry, error) {
	payload := struct {
		MatchType MatchType `json:"matchType"`
		Value     string    `json:"value"`
	}{matchType, value}

	var result ListEntry
	if err := c.doJSON(ctx, http.MethodPost, path, nil, payload, &result); err != nil {
		return nil, err
	}
	return &result, nil
}

// doJSON builds an authenticated request with an optional query and JSON body.
// out may be nil for responses with no body (204).
func (c *Client) doJSON(ctx context.Context, method, path string, query url.Values, payload, out interface{}) error {
	target := c.baseURL + path
	if len(query) > 0 {
		target += "?" + query.Encode()
	}

	var body io.Reader
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			return fmt.Errorf("skanqrcode: encode request: %w", err)
		}
		body = bytes.NewReader(encoded)
	}

	req, err := http.NewRequestWithContext(ctx, method, target, body)
	if err != nil {
		return fmt.Errorf("skanqrcode: build request: %w", err)
	}
	if payload != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	return c.do(req, true, out)
}

func (c *Client) do(req *http.Request, auth bool, out interface{}) error {
	if auth {
		req.Header.Set("Authorization", "Bearer "+c.apiKey)
	}

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
		apiErr := &APIError{
			Code:       ErrCodeInternal,
			Message:    string(respBody),
			RequestID:  resp.Header.Get("X-Request-Id"),
			StatusCode: resp.StatusCode,
		}
		if secs, err := strconv.Atoi(resp.Header.Get("Retry-After")); err == nil && secs >= 0 {
			apiErr.RetryAfter = time.Duration(secs) * time.Second
		}

		// A body that isn't the documented JSON (e.g. a proxy's HTML 502) keeps the
		// synthetic internal code.
		var errBody apiErrorBody
		if json.Unmarshal(respBody, &errBody) == nil && errBody.Error.Code != "" {
			apiErr.Code = errBody.Error.Code
			apiErr.Message = errBody.Error.Message
			if errBody.Error.RequestID != "" {
				apiErr.RequestID = errBody.Error.RequestID
			}
		}
		return apiErr
	}

	// 204 No Content (and any other bodyless success) has nothing to decode.
	if out == nil || resp.StatusCode == http.StatusNoContent {
		return nil
	}
	if err := json.Unmarshal(respBody, out); err != nil {
		return fmt.Errorf("skanqrcode: decode response: %w", err)
	}
	return nil
}
