package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

const baseURL = "https://api.skanqrcode.com"

type checkRequest struct {
	Target string `json:"target"`
}

type checkResponse struct {
	Verdict         string   `json:"verdict"`
	Action          string   `json:"action"`
	Mode            string   `json:"mode"`
	Reasons         []string `json:"reasons"`
	Cached          bool     `json:"cached"`
	ExecutionTimeMs int      `json:"executionTimeMs"`
	Environment     string   `json:"environment"`
	RequestID       string   `json:"requestId"`
}

type errorResponse struct {
	Error struct {
		Code      string `json:"code"`
		Message   string `json:"message"`
		RequestID string `json:"requestId"`
	} `json:"error"`
}

func main() {
	apiKey := os.Getenv("SKANQRCODE_API_KEY")
	if apiKey == "" {
		fmt.Fprintln(os.Stderr, "SKANQRCODE_API_KEY is not set")
		os.Exit(1)
	}

	target := "https://example.com/login"
	if len(os.Args) > 1 {
		target = os.Args[1]
	}

	result, err := checkURL(apiKey, target)
	if err != nil {
		fmt.Fprintf(os.Stderr, "check failed: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("verdict:         %s\n", result.Verdict)
	fmt.Printf("action:          %s\n", result.Action)
	fmt.Printf("mode:            %s\n", result.Mode)
	fmt.Printf("reasons:         %v\n", result.Reasons)
	fmt.Printf("cached:          %t\n", result.Cached)
	fmt.Printf("executionTimeMs: %d\n", result.ExecutionTimeMs)
	fmt.Printf("environment:     %s\n", result.Environment)
	fmt.Printf("requestId:       %s\n", result.RequestID)

	if result.Action == "block" {
		fmt.Println("\nBLOCK: do not open this link.")
	} else if result.Action == "warn" {
		fmt.Println("\nWARN: proceed with caution.")
	}
	if result.Environment == "sandbox" {
		fmt.Println("(sandbox key: results are for integration testing only)")
	}
}

func checkURL(apiKey, target string) (*checkResponse, error) {
	body, err := json.Marshal(checkRequest{Target: target})
	if err != nil {
		return nil, fmt.Errorf("encode request: %w", err)
	}

	req, err := http.NewRequest(http.MethodPost, baseURL+"/v1/check", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{Timeout: 5 * time.Second}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("send request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		var apiErr errorResponse
		if err := json.Unmarshal(respBody, &apiErr); err != nil || apiErr.Error.Code == "" {
			// Not the documented JSON (e.g. an HTML 502 from a proxy).
			return nil, fmt.Errorf("internal: http %d: %s", resp.StatusCode, string(respBody))
		}
		msg := fmt.Sprintf("%s: %s (http %d, requestId=%s)", apiErr.Error.Code, apiErr.Error.Message, resp.StatusCode, apiErr.Error.RequestID)
		switch apiErr.Error.Code {
		case "rate_limited":
			msg += fmt.Sprintf("; retry in %ss", resp.Header.Get("Retry-After"))
		case "quota_exceeded":
			msg += "; monthly quota exhausted, retrying won't help"
		}
		return nil, errors.New(msg)
	}

	var result checkResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	return &result, nil
}
