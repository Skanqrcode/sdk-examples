package com.skanqrcode.sdk;

public final class UsageHour {
    private final String hour;
    private final String mode;
    private final int total;
    private final double capacityUsedPercent;
    private final int blockedRpm;
    private final int blockedQuota;
    private final int malicious;
    private final int suspicious;
    private final int notMalicious;
    private final int cached;

    public UsageHour(String hour, String mode, int total, double capacityUsedPercent, int blockedRpm,
                      int blockedQuota, int malicious, int suspicious, int notMalicious, int cached) {
        this.hour = hour;
        this.mode = mode;
        this.total = total;
        this.capacityUsedPercent = capacityUsedPercent;
        this.blockedRpm = blockedRpm;
        this.blockedQuota = blockedQuota;
        this.malicious = malicious;
        this.suspicious = suspicious;
        this.notMalicious = notMalicious;
        this.cached = cached;
    }

    public String getHour() {
        return hour;
    }

    public String getMode() {
        return mode;
    }

    public int getTotal() {
        return total;
    }

    /** total / hourlyCapacity * 100, one decimal. Near 100 means that hour ran at the rate limit. */
    public double getCapacityUsedPercent() {
        return capacityUsedPercent;
    }

    /** Requests blocked that hour for exceeding the per-minute limit. */
    public int getBlockedRpm() {
        return blockedRpm;
    }

    /** Requests blocked that hour for exceeding the monthly quota. */
    public int getBlockedQuota() {
        return blockedQuota;
    }

    public int getMalicious() {
        return malicious;
    }

    public int getSuspicious() {
        return suspicious;
    }

    public int getNotMalicious() {
        return notMalicious;
    }

    public int getCached() {
        return cached;
    }
}
