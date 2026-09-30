package com.skanqrcode.sdk;

/**
 * The API's closed set of {@code error.code} values. {@link SkanQRCodeException#getCode()} is
 * still a plain string, so a code added later doesn't break the client — compare against these
 * constants and keep a default branch.
 */
public final class ErrorCode {
    public static final String INVALID_REQUEST = "invalid_request";
    public static final String UNAUTHORIZED = "unauthorized";
    public static final String PAYMENT_REQUIRED = "payment_required";
    public static final String FORBIDDEN = "forbidden";
    public static final String PLAN_FEATURE_UNAVAILABLE = "plan_feature_unavailable";
    public static final String NOT_FOUND = "not_found";
    public static final String RATE_LIMITED = "rate_limited";
    public static final String QUOTA_EXCEEDED = "quota_exceeded";
    public static final String AUTH_UNAVAILABLE = "auth_unavailable";
    public static final String INTERNAL = "internal";

    private ErrorCode() {
    }
}
