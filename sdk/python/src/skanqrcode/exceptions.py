from __future__ import annotations


class ErrorCode:
    """Known values of `error.code`. The set is closed today, but `SkanQRCodeError.code`
    is a plain string so a code added later still deserializes."""

    INVALID_REQUEST = "invalid_request"
    UNAUTHORIZED = "unauthorized"
    FORBIDDEN = "forbidden"
    NOT_FOUND = "not_found"
    PLAN_FEATURE_UNAVAILABLE = "plan_feature_unavailable"
    PAYMENT_REQUIRED = "payment_required"
    RATE_LIMITED = "rate_limited"
    QUOTA_EXCEEDED = "quota_exceeded"
    AUTH_UNAVAILABLE = "auth_unavailable"
    INTERNAL = "internal"


class SkanQRCodeError(Exception):
    """Raised on any non-2xx response.

    `retry_after` is the `Retry-After` header in seconds (429s), or None. If the error body
    wasn't the documented JSON (e.g. an HTML 502 from a proxy), `code` is "internal".
    """

    def __init__(
        self,
        code: str,
        message: str,
        request_id: str | None,
        status_code: int,
        retry_after: float | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.request_id = request_id
        self.status_code = status_code
        self.retry_after = retry_after
