package com.skanqrcode.sdk;

public final class HealthResponse {
    private final String status;

    public HealthResponse(String status) {
        this.status = status;
    }

    /** Always "ok". Liveness only — says nothing about the freshness of the data behind verdicts. */
    public String getStatus() {
        return status;
    }
}
