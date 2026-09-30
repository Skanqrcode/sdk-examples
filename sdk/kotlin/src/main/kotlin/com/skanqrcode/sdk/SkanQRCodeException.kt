package com.skanqrcode.sdk

/**
 * @property code an [ErrorCode] value (or a newer code this SDK doesn't know yet)
 * @property retryAfter seconds from the `Retry-After` header (429 responses), or null
 */
class SkanQRCodeException(
    val code: String,
    message: String,
    val requestId: String?,
    val httpStatus: Int,
    val retryAfter: Int? = null,
) : Exception("$code ($httpStatus): $message")

/**
 * The API's closed set of `error.code` values. [SkanQRCodeException.code] is still a plain
 * string, so a code added later doesn't break the client — compare against these constants and
 * keep an `else` branch.
 */
object ErrorCode {
    const val INVALID_REQUEST = "invalid_request"
    const val UNAUTHORIZED = "unauthorized"
    const val PAYMENT_REQUIRED = "payment_required"
    const val FORBIDDEN = "forbidden"
    const val PLAN_FEATURE_UNAVAILABLE = "plan_feature_unavailable"
    const val NOT_FOUND = "not_found"
    const val RATE_LIMITED = "rate_limited"
    const val QUOTA_EXCEEDED = "quota_exceeded"
    const val AUTH_UNAVAILABLE = "auth_unavailable"
    const val INTERNAL = "internal"
}
