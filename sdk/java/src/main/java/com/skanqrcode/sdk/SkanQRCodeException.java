package com.skanqrcode.sdk;

public class SkanQRCodeException extends Exception {
    private final String code;
    private final String requestId;
    private final int httpStatus;
    private final Integer retryAfter;

    /**
     * @param code       an {@link ErrorCode} value (or a newer code this SDK doesn't know yet)
     * @param retryAfter seconds from the {@code Retry-After} header, or null if absent
     */
    public SkanQRCodeException(String code, String message, String requestId, int httpStatus, Integer retryAfter) {
        super(code + " (" + httpStatus + "): " + message);
        this.code = code;
        this.requestId = requestId;
        this.httpStatus = httpStatus;
        this.retryAfter = retryAfter;
    }

    public String getCode() {
        return code;
    }

    public String getRequestId() {
        return requestId;
    }

    public int getHttpStatus() {
        return httpStatus;
    }

    /** Seconds to wait before retrying (429 responses), or null. */
    public Integer getRetryAfter() {
        return retryAfter;
    }
}
