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
        val code = extractString(response.body(), "code")
        val message = extractString(response.body(), "message")
        val requestId = extractString(response.body(), "requestId")
        System.err.println("SkanQRCode error [$code]: $message (requestId=$requestId)")
        return
    }

    val verdict = extractString(response.body(), "verdict")
    val score = extractNumber(response.body(), "score")
    val cached = extractBoolean(response.body(), "cached")
    val partial = extractBoolean(response.body(), "partial")
    val requestId = extractString(response.body(), "requestId")

    println("verdict=$verdict score=$score cached=$cached partial=$partial requestId=$requestId")

    when (verdict) {
        "malicious" -> println("BLOCK: do not open $target")
        "suspicious" -> println("WARN: confirm with the user before opening $target")
        "not_malicious" -> println("PROCEED: safe to open $target")
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
