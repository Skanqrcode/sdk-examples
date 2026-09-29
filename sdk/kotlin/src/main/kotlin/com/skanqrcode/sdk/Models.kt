package com.skanqrcode.sdk

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class Verdict {
    @SerialName("malicious") MALICIOUS,
    @SerialName("suspicious") SUSPICIOUS,
    @SerialName("not_malicious") NOT_MALICIOUS,
}

@Serializable
enum class Mode {
    @SerialName("url") URL,
    @SerialName("ip") IP,
}

enum class Recommendation { PROCEED, WARN, BLOCK }

val Verdict.recommendation: Recommendation
    get() = when (this) {
        Verdict.MALICIOUS -> Recommendation.BLOCK
        Verdict.SUSPICIOUS -> Recommendation.WARN
        Verdict.NOT_MALICIOUS -> Recommendation.PROCEED
    }

@Serializable
data class CheckResult(
    val verdict: Verdict,
    val mode: Mode,
    val score: Int,
    val reasons: List<String>,
    val cached: Boolean,
    val partial: Boolean,
    val requestId: String,
) {
    val recommendation: Recommendation get() = verdict.recommendation
}

@Serializable
data class UsageHour(
    val hour: String,
    val mode: Mode,
    val total: Int,
    val malicious: Int,
    val suspicious: Int,
    val notMalicious: Int,
    val cached: Int,
    val partial: Int,
)

@Serializable
data class UsageResponse(
    val tenantId: String,
    val from: String,
    val to: String,
    val hours: List<UsageHour>,
)

@Serializable
internal data class CheckRequest(val target: String)

@Serializable
internal data class ApiErrorBody(val error: ApiError)

@Serializable
internal data class ApiError(
    val code: String,
    val message: String,
    val requestId: String? = null,
)
