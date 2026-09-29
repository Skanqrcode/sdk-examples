/// Typed error surfaced for any non-2xx response from the SkanQRCode API,
/// so callers can branch on [code] instead of parsing a generic HTTP
/// exception.
class SkanQRCodeException implements Exception {
  const SkanQRCodeException({
    required this.code,
    required this.message,
    required this.requestId,
    required this.httpStatus,
  });

  /// Machine-readable error code, e.g. `invalid_target`, `invalid_api_key`,
  /// `tenant_suspended`, `rate_limited`.
  final String code;

  final String message;

  /// Correlates this error with server-side logs/support requests.
  final String requestId;

  final int httpStatus;

  /// `true` for errors a well-behaved client may retry with backoff: 429
  /// (after `Retry-After`) and 5xx. 400/401/402 are not retryable.
  bool get isRetryable => httpStatus == 429 || httpStatus >= 500;

  @override
  String toString() =>
      'SkanQRCodeException($httpStatus $code: $message, requestId: $requestId)';
}
