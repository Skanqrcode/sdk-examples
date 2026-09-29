# skanqrcode-go

Go SDK for the SkanQRCode URL/QR-code safety API.

## Install

```sh
go get github.com/skanqrcode/skanqrcode-go
```

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

	result, err := client.CheckURL(ctx, "https://example.com/login")
	if err != nil {
		var apiErr *skanqrcode.APIError
		if errors.As(err, &apiErr) {
			log.Fatalf("skanqrcode error %s: %s (requestId=%s)", apiErr.Code, apiErr.Message, apiErr.RequestID)
		}
		log.Fatal(err)
	}

	switch result.Recommendation() {
	case skanqrcode.RecommendationBlock:
		fmt.Println("blocked:", result.Reasons)
	case skanqrcode.RecommendationWarn:
		fmt.Println("warn user before proceeding:", result.Reasons)
	case skanqrcode.RecommendationProceed:
		fmt.Println("safe to open")
	}
}
```

See [../../docs/api-contract.md](../../docs/api-contract.md) for the full API contract.
