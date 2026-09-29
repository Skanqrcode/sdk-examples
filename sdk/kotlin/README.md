# skanqrcode-sdk (Kotlin)

A typed Kotlin client for the SkanQRCode API. See
[`../../docs/api-contract.md`](../../docs/api-contract.md) for the full HTTP contract this
wraps.

## Install

```kotlin
dependencies {
    implementation("com.skanqrcode:skanqrcode-sdk:1.0.0")
}
```

## Usage

```kotlin
import com.skanqrcode.sdk.Recommendation
import com.skanqrcode.sdk.SkanQRCodeClient
import com.skanqrcode.sdk.SkanQRCodeException

suspend fun main() {
    val client = SkanQRCodeClient(apiKey = System.getenv("SKANQRCODE_API_KEY"))

    try {
        val result = client.checkUrl("https://example.com/login")
        when (result.recommendation) {
            Recommendation.PROCEED -> println("safe to open")
            Recommendation.WARN -> println("warn: ${result.reasons}")
            Recommendation.BLOCK -> println("blocked: ${result.reasons}")
        }
    } catch (e: SkanQRCodeException) {
        println("${e.code}: ${e.message} (requestId=${e.requestId})")
    }
}
```
