package com.skanqrcode.sdk

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

class SkanQRCodeClient(
    private val apiKey: String,
    private val baseUrl: String = "https://api.skanqrcode.com",
    private val timeoutMs: Long = 5000,
) {
    private val http: HttpClient = HttpClient.newBuilder()
        .connectTimeout(Duration.ofMillis(timeoutMs))
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Classifies a URL or IP address. Consumes one unit of monthly quota.
     * [userId] is an optional opaque end-user id that enables per-user caching; only sent when set.
     */
    suspend fun checkUrl(target: String, userId: String? = null): CheckResult =
        post("/v1/check", json.encodeToString(CheckRequest.serializer(), CheckRequest(target, userId)), CheckResult.serializer())

    /** Monthly usage summary. [month] is YYYY-MM (UTC); null means the current month. */
    suspend fun getUsage(month: String? = null): UsageResponse =
        get("/v1/usage" + query("month" to month), UsageResponse.serializer())

    /** Hour-by-hour usage with per-minute rate-limit utilization. [month] is YYYY-MM (UTC); null means the current month. */
    suspend fun getUsageHourly(month: String? = null): HourlyUsageResponse =
        get("/v1/usage/hourly" + query("month" to month), HourlyUsageResponse.serializer())

    /** Lists allow-list entries, newest first. Pro and Business plans only. */
    suspend fun listAllowList(limit: Int? = null, cursor: String? = null): ListEntriesResponse =
        get("/v1/allow-list" + query("limit" to limit?.toString(), "cursor" to cursor), ListEntriesResponse.serializer())

    /** Adds an allow-list entry (idempotent). Needs an admin-scope key; Pro and Business plans only. */
    suspend fun addAllowListEntry(matchType: MatchType, value: String): ListEntry =
        post("/v1/allow-list", addEntryBody(matchType, value), ListEntry.serializer())

    /** Removes an allow-list entry. Needs an admin-scope key; Pro and Business plans only. */
    suspend fun deleteAllowListEntry(entryId: String) = delete("/v1/allow-list/${encodePathSegment(entryId)}")

    /** Lists block-list entries, newest first. Every plan. */
    suspend fun listBlockList(limit: Int? = null, cursor: String? = null): ListEntriesResponse =
        get("/v1/block-list" + query("limit" to limit?.toString(), "cursor" to cursor), ListEntriesResponse.serializer())

    /** Adds a block-list entry (idempotent). Needs an admin-scope key. */
    suspend fun addBlockListEntry(matchType: MatchType, value: String): ListEntry =
        post("/v1/block-list", addEntryBody(matchType, value), ListEntry.serializer())

    /** Removes a block-list entry. Needs an admin-scope key. */
    suspend fun deleteBlockListEntry(entryId: String) = delete("/v1/block-list/${encodePathSegment(entryId)}")

    /**
     * Starts a subscription checkout. Human-in-the-loop: needs an admin-scope key and a Turnstile
     * token minted by a real browser, and the returned URL is for a person to open — an
     * autonomous agent must hand it to a human, never complete checkout itself.
     *
     * @param planId "pro" or "business"
     */
    suspend fun createCheckoutSession(planId: String, turnstileToken: String): SessionUrlResponse =
        post("/v1/billing/checkout", json.encodeToString(CheckoutRequest.serializer(), CheckoutRequest(planId, turnstileToken)), SessionUrlResponse.serializer())

    /**
     * Opens the billing portal. Human-in-the-loop: needs an admin-scope key, and the returned URL
     * is for a person to open — never something an autonomous agent should act on itself.
     */
    suspend fun createPortalSession(): SessionUrlResponse =
        post("/v1/billing/portal", null, SessionUrlResponse.serializer())

    /** Liveness check. No API key needed. */
    suspend fun getHealth(): HealthResponse =
        get("/health", HealthResponse.serializer(), authenticated = false)

    private suspend fun <T> get(path: String, serializer: KSerializer<T>, authenticated: Boolean = true): T =
        withContext(Dispatchers.IO) {
            parseOrThrow(send(request(path, authenticated).GET().build()), serializer)
        }

    // Covers both 201 (created) and 200 (already existed) for the add-entry calls.
    private suspend fun <T> post(path: String, body: String?, serializer: KSerializer<T>): T =
        withContext(Dispatchers.IO) {
            val builder = request(path, authenticated = true)
            if (body != null) {
                builder.header("Content-Type", "application/json").POST(HttpRequest.BodyPublishers.ofString(body))
            } else {
                builder.POST(HttpRequest.BodyPublishers.noBody())
            }
            parseOrThrow(send(builder.build()), serializer)
        }

    // 204 has no body — only look at the status.
    private suspend fun delete(path: String): Unit = withContext(Dispatchers.IO) {
        val response = send(request(path, authenticated = true).DELETE().build())
        if (response.statusCode() !in 200..299) throw toException(response)
    }

    private fun request(path: String, authenticated: Boolean): HttpRequest.Builder {
        val builder = HttpRequest.newBuilder()
            .uri(URI.create("$baseUrl$path"))
            .timeout(Duration.ofMillis(timeoutMs))
        if (authenticated) builder.header("Authorization", "Bearer $apiKey")
        return builder
    }

    private fun send(request: HttpRequest): HttpResponse<String> =
        http.send(request, HttpResponse.BodyHandlers.ofString())

    private fun <T> parseOrThrow(response: HttpResponse<String>, serializer: KSerializer<T>): T {
        if (response.statusCode() !in 200..299) throw toException(response)
        try {
            return json.decodeFromString(serializer, response.body())
        } catch (e: SerializationException) {
            throw malformed(e, response.statusCode())
        } catch (e: IllegalArgumentException) {
            throw malformed(e, response.statusCode())
        }
    }

    // Builds the typed exception for a non-2xx response. A body that isn't the documented
    // JSON (e.g. a proxy's HTML 502) becomes code "internal" with the HTTP status.
    private fun toException(response: HttpResponse<String>): SkanQRCodeException {
        val error = runCatching { json.decodeFromString(ApiErrorBody.serializer(), response.body()) }.getOrNull()?.error
        return SkanQRCodeException(
            code = error?.code ?: ErrorCode.INTERNAL,
            message = error?.message ?: "HTTP ${response.statusCode()}",
            requestId = error?.requestId,
            httpStatus = response.statusCode(),
            retryAfter = response.headers().firstValue("Retry-After").orElse(null)?.trim()?.toIntOrNull(),
        )
    }

    private fun malformed(cause: Exception, status: Int) =
        SkanQRCodeException(ErrorCode.INTERNAL, "Unexpected response body: ${cause.message}", null, status).also { it.initCause(cause) }

    private fun addEntryBody(matchType: MatchType, value: String) =
        json.encodeToString(AddListEntryRequest.serializer(), AddListEntryRequest(matchType, value))

    // Builds "?k=v&k=v", skipping null values; "" if nothing is set.
    private fun query(vararg params: Pair<String, String?>): String =
        params.filter { it.second != null }
            .joinToString("&", prefix = "?") { "${it.first}=${encode(it.second!!)}" }
            .let { if (it == "?") "" else it }

    private fun encode(value: String): String = URLEncoder.encode(value, StandardCharsets.UTF_8)

    private fun encodePathSegment(value: String): String = encode(value).replace("+", "%20")
}
