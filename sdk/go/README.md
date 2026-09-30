# skanqrcode-go

Go SDK for the SkanQRCode URL/QR-code safety API.

## Install

```sh
go get github.com/skanqrcode/skanqrcode-go
```

Use an `sk_test_` key (free sandbox plan) while integrating; paid plans get an `sk_live_` key.

## Usage

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/skanqrcode/skanqrcode-go"
)

func main() {
	client := skanqrcode.New(os.Getenv("SKANQRCODE_API_KEY"))

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// WithUserID is optional; it enables per-user result caching.
	result, err := client.CheckURL(ctx, "https://example.com/login", skanqrcode.WithUserID("user-4821"))
	if err != nil {
		var apiErr *skanqrcode.APIError
		if errors.As(err, &apiErr) {
			if apiErr.Code == skanqrcode.ErrCodeRateLimited {
				log.Fatalf("rate limited, retry in %s (requestId=%s)", apiErr.RetryAfter, apiErr.RequestID)
			}
			log.Fatalf("skanqrcode error %s: %s (requestId=%s)", apiErr.Code, apiErr.Message, apiErr.RequestID)
		}
		log.Fatal(err)
	}

	switch result.Action {
	case skanqrcode.ActionBlock:
		fmt.Println("blocked:", result.Reasons)
	case skanqrcode.ActionWarn:
		fmt.Println("warn user before proceeding:", result.Reasons)
	case skanqrcode.ActionAllow:
		fmt.Println("safe to open")
	}
}
```

`CheckResult` has `Verdict`, `Action` (`allow` / `warn` / `block`), `Mode`, `Reasons` (plain
strings), `FinalURL` (nil unless a redirect was followed), `Cached`, `ExecutionTimeMs`,
`Environment` (`sandbox` / `production`), `LicensedForProduction`, `RequestID`, and `Related` (IP
mode only). Branch on `Action`; `ShouldBlock()` and `IsSafe()` are shortcuts for block / allow,
and `warn` is neither. `ExecutionTimeMs >= 180` means the evaluation deadline was hit and the
result is best-effort. Sandbox results are for integration testing only.

## Usage and lists

```go
usage, err := client.GetUsage(ctx, "2026-09") // "" for the current month
fmt.Println(usage.TotalRequests, usage.AvailableRequests, usage.MonthlyQuota)

hourly, err := client.GetUsageHourly(ctx, "2026-09")
for _, h := range hourly.Hours {
	fmt.Println(h.Hour, h.Total, h.CapacityUsedPercent, h.BlockedRpm)
}

// Block list (every plan); the allow list (Pro and Business) has the same methods.
entry, err := client.AddBlockListEntry(ctx, skanqrcode.MatchTypeDomain, "malicious-example.com") // admin-scope key
page, err := client.ListBlockList(ctx, &skanqrcode.ListOptions{Limit: 100})
for page.NextCursor != nil {
	page, err = client.ListBlockList(ctx, &skanqrcode.ListOptions{Limit: 100, Cursor: *page.NextCursor})
}
err = client.DeleteBlockListEntry(ctx, entry.ID)
```

Also available: `ListAllowList`, `AddAllowListEntry`, `DeleteAllowListEntry`, and `GetHealth` (no
key needed). `CreateCheckoutSession(ctx, planID, turnstileToken)` and `CreatePortalSession(ctx)`
are human-in-the-loop, admin-scope calls: hand the returned URL to a person rather than
completing checkout from an agent.

## Error handling

Every non-2xx response is an `*skanqrcode.APIError` with `Code`, `Message`, `RequestID`,
`StatusCode` and, for 429s, `RetryAfter` (zero if the header is absent). `Code` is one of the
`ErrCode*` constants (`invalid_request`, `unauthorized`, `forbidden`, `not_found`,
`plan_feature_unavailable`, `payment_required`, `rate_limited`, `quota_exceeded`,
`auth_unavailable`, `internal`); a code added later still comes through as a string. A non-JSON
error body (such as a proxy's HTML 502) is returned as `ErrCodeInternal` with the HTTP status. The
SDK doesn't retry: retry `rate_limited` after `RetryAfter`, `auth_unavailable` shortly and 5xx
with backoff, never `quota_exceeded` or 4xx. Fail closed if a check errors.

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
