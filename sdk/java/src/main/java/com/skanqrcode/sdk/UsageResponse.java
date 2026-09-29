package com.skanqrcode.sdk;

import java.util.List;

public final class UsageResponse {
    private final String tenantId;
    private final String from;
    private final String to;
    private final List<UsageHour> hours;

    public UsageResponse(String tenantId, String from, String to, List<UsageHour> hours) {
        this.tenantId = tenantId;
        this.from = from;
        this.to = to;
        this.hours = hours;
    }

    public String getTenantId() {
        return tenantId;
    }

    public String getFrom() {
        return from;
    }

    public String getTo() {
        return to;
    }

    public List<UsageHour> getHours() {
        return hours;
    }
}
