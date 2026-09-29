# skanqrcode-sdk (Java)

A typed, blocking Java client for the SkanQRCode API. See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full HTTP contract this
wraps.

## Install

```xml
<dependency>
  <groupId>com.skanqrcode</groupId>
  <artifactId>skanqrcode-sdk</artifactId>
  <version>1.0.0</version>
</dependency>
```

## Usage

```java
import com.skanqrcode.sdk.CheckResult;
import com.skanqrcode.sdk.Recommendation;
import com.skanqrcode.sdk.SkanQRCodeClient;
import com.skanqrcode.sdk.SkanQRCodeException;

public class Example {
    public static void main(String[] args) throws Exception {
        SkanQRCodeClient client = new SkanQRCodeClient(System.getenv("SKANQRCODE_API_KEY"));

        try {
            CheckResult result = client.checkUrl("https://example.com/login");
            switch (result.getRecommendation()) {
                case PROCEED -> System.out.println("safe to open");
                case WARN -> System.out.println("warn: " + result.getReasons());
                case BLOCK -> System.out.println("blocked: " + result.getReasons());
            }
        } catch (SkanQRCodeException e) {
            System.out.println(e.getCode() + ": " + e.getMessage() + " (requestId=" + e.getRequestId() + ")");
        }
    }
}
```

## Usage aggregates

```java
UsageResponse usage = client.getUsage(Instant.parse("2026-09-01T00:00:00Z"), Instant.parse("2026-09-02T00:00:00Z"));
for (UsageHour hour : usage.getHours()) {
    System.out.println(hour.getHour() + " " + hour.getMode() + ": " + hour.getTotal() + " checks");
}
```
