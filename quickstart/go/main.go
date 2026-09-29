package main

import (
	"bytes"
	"encoding/json"
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
	Verdict   string   `json:"verdict"`
	Mode      string   `json:"mode"`
	Score     int      `json:"score"`
	Reasons   []string `json:"reasons"`
	Cached    bool     `json:"cached"`
	Partial   bool     `json:"partial"`
	RequestID string   `json:"requestId"`
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

	fmt.Printf("verdict:    %s\n", result.Verdict)
	fmt.Printf("mode:       %s\n", result.Mode)
	fmt.Printf("score:      %d\n", result.Score)
	fmt.Printf("reasons:    %v\n", result.Reasons)
	fmt.Printf("cached:     %t\n", result.Cached)
	fmt.Printf("partial:    %t\n", result.Partial)
	fmt.Printf("requestId:  %s\n", result.RequestID)

	if result.Verdict == "malicious" {
		fmt.Println("\nBLOCK: do not open this link.")
	} else if result.Verdict == "suspicious" {
		fmt.Println("\nWARN: proceed with caution.")
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
		if err := json.Unmarshal(respBody, &apiErr); err != nil {
			return nil, fmt.Errorf("http %d: %s", resp.StatusCode, string(respBody))
		}
		return nil, fmt.Errorf("%s: %s (requestId=%s)", apiErr.Error.Code, apiErr.Error.Message, apiErr.Error.RequestID)
	}

	var result checkResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, fmt.Errorf("decode response: %w", err)
	}

	return &result, nil
}
