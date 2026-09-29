package com.skanqrcode.sdk;

public final class UsageHour {
    private final String hour;
    private final String mode;
    private final int total;
    private final int malicious;
    private final int suspicious;
    private final int notMalicious;
    private final int cached;
    private final int partial;

    public UsageHour(String hour, String mode, int total, int malicious, int suspicious,
                      int notMalicious, int cached, int partial) {
        this.hour = hour;
        this.mode = mode;
        this.total = total;
        this.malicious = malicious;
        this.suspicious = suspicious;
        this.notMalicious = notMalicious;
        this.cached = cached;
        this.partial = partial;
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

    public int getPartial() {
        return partial;
    }
}
