package com.skanqrcode.sdk;

public final class UsageResponse {
    private final String tenantId;
    private final String month;
    private final int monthlyQuota;
    private final int totalRequests;
    private final int availableRequests;

    public UsageResponse(String tenantId, String month, int monthlyQuota, int totalRequests,
                          int availableRequests) {
        this.tenantId = tenantId;
        this.month = month;
        this.monthlyQuota = monthlyQuota;
        this.totalRequests = totalRequests;
        this.availableRequests = availableRequests;
    }

    public String getTenantId() {
        return tenantId;
    }

    /** The UTC calendar month covered, as YYYY-MM. */
    public String getMonth() {
        return month;
    }

    public int getMonthlyQuota() {
        return monthlyQuota;
    }

    public int getTotalRequests() {
        return totalRequests;
    }

    /** max(monthlyQuota - totalRequests, 0). Figures can lag real time by up to about an hour. */
    public int getAvailableRequests() {
        return availableRequests;
    }
}
