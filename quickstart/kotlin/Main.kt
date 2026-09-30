import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

private const val BASE_URL = "https://api.skanqrcode.com"

fun main() {
    val apiKey = System.getenv("SKANQRCODE_API_KEY")
        ?: error("Set SKANQRCODE_API_KEY to your SkanQRCode API key")

    val target = "https://example.com/login"

    val client = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build()

    val request = HttpRequest.newBuilder()
        .uri(URI.create("$BASE_URL/v1/check"))
        .timeout(Duration.ofSeconds(5))
        .header("Authorization", "Bearer $apiKey")
        .header("Content-Type", "application/json")
        .POST(HttpRequest.BodyPublishers.ofString("""{"target":"${escapeJson(target)}"}"""))
        .build()

    val response = client.send(request, HttpResponse.BodyHandlers.ofString())

    if (response.statusCode() != 200) {
        // Error bodies are {"error":{"code","message","requestId"}}; a proxy may return HTML instead.
        val code = extractString(response.body(), "code") ?: "internal"
        val message = extractString(response.body(), "message")
        val requestId = extractString(response.body(), "requestId")
        val retryAfter = response.headers().firstValue("Retry-After").orElse(null)
        System.err.println("SkanQRCode error [$code] HTTP ${response.statusCode()}: $message (requestId=$requestId)")
        when (code) {
            "rate_limited" -> System.err.println("Too many requests: retry in ${retryAfter}s")
            "quota_exceeded", "payment_required", "unauthorized" ->
                System.err.println("Configuration problem (key, plan or quota) - retrying won't help")
        }
        return
    }

    val verdict = extractString(response.body(), "verdict")
    val action = extractString(response.body(), "action")
    val executionTimeMs = extractNumber(response.body(), "executionTimeMs")
    val environment = extractString(response.body(), "environment")
    val cached = extractBoolean(response.body(), "cached")
    val requestId = extractString(response.body(), "requestId")

    println("verdict=$verdict action=$action executionTimeMs=$executionTimeMs environment=$environment cached=$cached requestId=$requestId")
    if (environment == "sandbox") println("(sandbox key: results are for integration testing only)")

    // Branch on action, not verdict. Anything unexpected is treated as "don't open".
    when (action) {
        "allow" -> println("ALLOW: safe to open $target")
        "warn" -> println("WARN: confirm with the user before opening $target")
        else -> println("BLOCK: do not open $target")
    }
}

// Hand-rolled extraction to keep this quickstart dependency-free — it targets the one
// fixed response shape in docs/api-contract.md. For typed (de)serialization, see sdk/kotlin.
private fun extractString(json: String, field: String): String? =
    Regex(""""$field"\s*:\s*"((?:[^"\\]|\\.)*)"""").find(json)?.groupValues?.get(1)?.let(::unescapeJson)

private fun extractNumber(json: String, field: String): Int? =
    Regex(""""$field"\s*:\s*(-?\d+)""").find(json)?.groupValues?.get(1)?.toIntOrNull()

private fun extractBoolean(json: String, field: String): Boolean? =
    Regex(""""$field"\s*:\s*(true|false)""").find(json)?.groupValues?.get(1)?.toBoolean()

private fun escapeJson(s: String): String =
    s.replace("\\", "\\\\").replace("\"", "\\\"")

private fun unescapeJson(s: String): String =
    s.replace("\\\"", "\"").replace("\\\\", "\\")
