package com.skanqrcode.sdk;

public class SkanQRCodeException extends Exception {
    private final String code;
    private final String requestId;
    private final int httpStatus;

    public SkanQRCodeException(String code, String message, String requestId, int httpStatus) {
        super(code + " (" + httpStatus + "): " + message);
        this.code = code;
        this.requestId = requestId;
        this.httpStatus = httpStatus;
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
}
