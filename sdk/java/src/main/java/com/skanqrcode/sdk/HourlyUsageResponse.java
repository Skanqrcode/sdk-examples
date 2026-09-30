package com.skanqrcode.sdk;

import java.util.List;

public final class HourlyUsageResponse {
    private final String tenantId;
    private final String month;
    private final int rpmLimit;
    private final int hourlyCapacity;
    private final List<UsageHour> hours;

    public HourlyUsageResponse(String tenantId, String month, int rpmLimit, int hourlyCapacity,
                                List<UsageHour> hours) {
        this.tenantId = tenantId;
        this.month = month;
        this.rpmLimit = rpmLimit;
        this.hourlyCapacity = hourlyCapacity;
        this.hours = hours;
    }

    public String getTenantId() {
        return tenantId;
    }

    public String getMonth() {
        return month;
    }

    /** The plan's requests-per-minute limit. */
    public int getRpmLimit() {
        return rpmLimit;
    }

    /** rpmLimit * 60. A reading aid only — limits are enforced per minute, not per hour. */
    public int getHourlyCapacity() {
        return hourlyCapacity;
    }

    public List<UsageHour> getHours() {
        return hours;
    }
}
