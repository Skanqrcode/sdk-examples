package com.skanqrcode.sdk;

/** A host recently associated with a checked IP address (IP mode only). */
public final class RelatedHost {
    private final String host;
    private final Verdict verdict;

    public RelatedHost(String host, Verdict verdict) {
        this.host = host;
        this.verdict = verdict;
    }

    public String getHost() {
        return host;
    }

    public Verdict getVerdict() {
        return verdict;
    }

    @Override
    public String toString() {
        return "RelatedHost{host=" + host + ", verdict=" + verdict + "}";
    }
}
