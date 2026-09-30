package com.skanqrcode.sdk

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class Verdict {
    @SerialName("malicious") MALICIOUS,
    @SerialName("suspicious") SUSPICIOUS,
    @SerialName("not_malicious") NOT_MALICIOUS,
}

/** What the caller should do with a checked target. Server-provided; branch on this. */
@Serializable
enum class Action {
    @SerialName("allow") ALLOW,
    @SerialName("warn") WARN,
    @SerialName("block") BLOCK,
}

@Serializable
enum class Mode {
    @SerialName("url") URL,
    @SerialName("ip") IP,
}

@Serializable
enum class Environment {
    @SerialName("sandbox") SANDBOX,
    @SerialName("production") PRODUCTION,
}

/** What an allow-list / block-list entry matches. */
@Serializable
enum class MatchType {
    @SerialName("url") URL,
    @SerialName("host") HOST,
    @SerialName("domain") DOMAIN,
    @SerialName("ip") IP,
}

/** A host recently associated with a checked IP address (IP mode only). */
@Serializable
data class RelatedHost(
    val host: String,
    val verdict: Verdict,
)

@Serializable
data class CheckResult(
    val verdict: Verdict,
    /** Fixed mapping: not_malicious to ALLOW, suspicious to WARN, malicious to BLOCK. */
    val action: Action,
    val mode: Mode,
    /** Reason codes, kept as plain strings so a new code doesn't break parsing. */
    val reasons: List<String>,
    /** Where a shortened link resolved to, if a redirect was followed. */
    val finalUrl: String? = null,
    val cached: Boolean,
    /** Server-side evaluation time. At or above 180 the deadline was hit and the result is best-effort. */
    val executionTimeMs: Int,
    val environment: Environment,
    /** False on the free sandbox plan; treat those results as integration-test output only. */
    val licensedForProduction: Boolean,
    val requestId: String,
    /** Recently associated hosts (IP mode only); empty otherwise. */
    val related: List<RelatedHost> = emptyList(),
) {
    /** `action == BLOCK`. WARN is neither blocked nor safe — surface it to the user. */
    val shouldBlock: Boolean get() = action == Action.BLOCK

    /** `action == ALLOW`. WARN is neither blocked nor safe — surface it to the user. */
    val isSafe: Boolean get() = action == Action.ALLOW
}

/** Monthly usage summary. Figures can lag real time by up to about an hour. */
@Serializable
data class UsageResponse(
    val tenantId: String,
    /** The UTC calendar month covered, as YYYY-MM. */
    val month: String,
    val monthlyQuota: Int,
    val totalRequests: Int,
    /** max(monthlyQuota - totalRequests, 0). */
    val availableRequests: Int,
)

@Serializable
data class UsageHour(
    val hour: String,
    val mode: Mode,
    val total: Int,
    /** total / hourlyCapacity * 100, one decimal. Near 100 means that hour ran at the rate limit. */
    val capacityUsedPercent: Double,
    /** Requests blocked that hour for exceeding the per-minute limit. */
    val blockedRpm: Int,
    /** Requests blocked that hour for exceeding the monthly quota. */
    val blockedQuota: Int,
    val malicious: Int,
    val suspicious: Int,
    val notMalicious: Int,
    val cached: Int,
)

@Serializable
data class HourlyUsageResponse(
    val tenantId: String,
    val month: String,
    /** The plan's requests-per-minute limit. */
    val rpmLimit: Int,
    /** rpmLimit * 60. A reading aid only — limits are enforced per minute, not per hour. */
    val hourlyCapacity: Int,
    val hours: List<UsageHour>,
)

@Serializable
data class ListEntry(
    val id: String,
    val matchType: MatchType,
    /** For url entries only the registrable domain and a short hash hint are returned. */
    val value: String,
    /** RFC 3339, UTC. */
    val createdAt: String,
)

@Serializable
data class ListEntriesResponse(
    /** Newest first. */
    val entries: List<ListEntry>,
    /** Pass to the next list call for the following page; null on the last page. */
    val nextCursor: String? = null,
)

@Serializable
data class SessionUrlResponse(val url: String)

@Serializable
data class HealthResponse(
    /** Always "ok". Liveness only. */
    val status: String,
)

@Serializable
internal data class CheckRequest(val target: String, val userId: String? = null)

@Serializable
internal data class AddListEntryRequest(val matchType: MatchType, val value: String)

@Serializable
internal data class CheckoutRequest(val planId: String, val turnstileToken: String)

@Serializable
internal data class ApiErrorBody(val error: ApiError)

@Serializable
internal data class ApiError(
    val code: String? = null,
    val message: String? = null,
    val requestId: String? = null,
)
