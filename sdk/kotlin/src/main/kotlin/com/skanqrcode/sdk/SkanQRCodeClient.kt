package com.skanqrcode.sdk

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
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

    suspend fun checkUrl(target: String): CheckResult = withContext(Dispatchers.IO) {
        val request = HttpRequest.newBuilder()
            .uri(URI.create("$baseUrl/v1/check"))
            .timeout(Duration.ofMillis(timeoutMs))
            .header("Authorization", "Bearer $apiKey")
            .header("Content-Type", "application/json")
            .POST(HttpRequest.BodyPublishers.ofString(json.encodeToString(CheckRequest.serializer(), CheckRequest(target))))
            .build()

        val response = http.send(request, HttpResponse.BodyHandlers.ofString())
        parseOrThrow(response, CheckResult.serializer())
    }

    suspend fun getUsage(from: String, to: String): UsageResponse = withContext(Dispatchers.IO) {
        val query = "from=${encode(from)}&to=${encode(to)}"
        val request = HttpRequest.newBuilder()
            .uri(URI.create("$baseUrl/v1/usage?$query"))
            .timeout(Duration.ofMillis(timeoutMs))
            .header("Authorization", "Bearer $apiKey")
            .GET()
            .build()

        val response = http.send(request, HttpResponse.BodyHandlers.ofString())
        parseOrThrow(response, UsageResponse.serializer())
    }

    private fun <T> parseOrThrow(response: HttpResponse<String>, serializer: KSerializer<T>): T {
        if (response.statusCode() in 200..299) {
            return json.decodeFromString(serializer, response.body())
        }
        val body = runCatching { json.decodeFromString(ApiErrorBody.serializer(), response.body()) }.getOrNull()
        throw SkanQRCodeException(
            code = body?.error?.code ?: "unknown_error",
            message = body?.error?.message ?: response.body(),
            requestId = body?.error?.requestId,
            httpStatus = response.statusCode(),
        )
    }

    private fun encode(value: String): String = URLEncoder.encode(value, StandardCharsets.UTF_8)
}
