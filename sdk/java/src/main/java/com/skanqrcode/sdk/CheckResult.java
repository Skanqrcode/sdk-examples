package com.skanqrcode.sdk;

import java.util.List;

public final class CheckResult {
    private final Verdict verdict;
    private final String mode;
    private final int score;
    private final List<String> reasons;
    private final boolean cached;
    private final boolean partial;
    private final String requestId;

    public CheckResult(Verdict verdict, String mode, int score, List<String> reasons,
                        boolean cached, boolean partial, String requestId) {
        this.verdict = verdict;
        this.mode = mode;
        this.score = score;
        this.reasons = reasons;
        this.cached = cached;
        this.partial = partial;
        this.requestId = requestId;
    }

    public Verdict getVerdict() {
        return verdict;
    }

    public String getMode() {
        return mode;
    }

    public int getScore() {
        return score;
    }

    public List<String> getReasons() {
        return reasons;
    }

    public boolean isCached() {
        return cached;
    }

    public boolean isPartial() {
        return partial;
    }

    public String getRequestId() {
        return requestId;
    }

    public Recommendation getRecommendation() {
        switch (verdict) {
            case MALICIOUS:
                return Recommendation.BLOCK;
            case SUSPICIOUS:
                return Recommendation.WARN;
            case NOT_MALICIOUS:
                return Recommendation.PROCEED;
            default:
                throw new IllegalStateException("Unhandled verdict: " + verdict);
        }
    }

    @Override
    public String toString() {
        return "CheckResult{verdict=" + verdict + ", mode=" + mode + ", score=" + score
                + ", reasons=" + reasons + ", cached=" + cached + ", partial=" + partial
                + ", requestId=" + requestId + "}";
    }
}
