/// The documented `error.code` values (a closed set). [SkanQRCodeException.code]
/// is still a plain string, so a code added in a later API version surfaces
/// instead of failing to decode.
abstract final class ErrorCode {
  static const invalidRequest = 'invalid_request';
  static const unauthorized = 'unauthorized';
  static const forbidden = 'forbidden';
  static const notFound = 'not_found';
  static const planFeatureUnavailable = 'plan_feature_unavailable';
  static const paymentRequired = 'payment_required';
  static const rateLimited = 'rate_limited';
  static const quotaExceeded = 'quota_exceeded';
  static const authUnavailable = 'auth_unavailable';
  static const internal = 'internal';
}

/// Typed error surfaced for any non-2xx response from the SkanQRCode API,
/// so callers can branch on [code] instead of parsing a generic HTTP
/// exception.
class SkanQRCodeException implements Exception {
  const SkanQRCodeException({
    required this.code,
    required this.message,
    required this.httpStatus,
    this.requestId,
    this.retryAfter,
  });

  /// Machine-readable error code — branch on this, never on [message]. See
  /// [ErrorCode] for the documented set. A non-JSON error body (e.g. a proxy's
  /// HTML 502) yields a synthetic `internal`.
  final String code;

  final String message;

  /// Correlates this error with server-side logs/support requests. Taken from
  /// the error body, falling back to the `X-Request-Id` header; `null` if
  /// neither is present.
  final String? requestId;

  final int httpStatus;

  /// Seconds from the `Retry-After` header (429s); `null` if absent.
  final int? retryAfter;

  /// `true` when a caller may retry: `rate_limited` (after [retryAfter]),
  /// `auth_unavailable` (shortly) and 5xx (with backoff). `quota_exceeded` is
  /// also a 429 but won't clear until the quota resets or the plan changes.
  /// The SDK never retries on its own.
  bool get isRetryable =>
      code == ErrorCode.rateLimited ||
      code == ErrorCode.authUnavailable ||
      httpStatus >= 500;

  @override
  String toString() =>
      'SkanQRCodeException($httpStatus $code: $message, requestId: $requestId)';
}
