package com.skanqrcode.sdk;

import java.util.List;

public final class CheckResult {
    private final Verdict verdict;
    private final Action action;
    private final String mode;
    private final List<String> reasons;
    private final String finalUrl;
    private final boolean cached;
    private final int executionTimeMs;
    private final String environment;
    private final boolean licensedForProduction;
    private final String requestId;
    private final List<RelatedHost> related;

    public CheckResult(Verdict verdict, Action action, String mode, List<String> reasons, String finalUrl,
                        boolean cached, int executionTimeMs, String environment,
                        boolean licensedForProduction, String requestId, List<RelatedHost> related) {
        this.verdict = verdict;
        this.action = action;
        this.mode = mode;
        this.reasons = reasons;
        this.finalUrl = finalUrl;
        this.cached = cached;
        this.executionTimeMs = executionTimeMs;
        this.environment = environment;
        this.licensedForProduction = licensedForProduction;
        this.requestId = requestId;
        this.related = related;
    }

    public Verdict getVerdict() {
        return verdict;
    }

    /** What to do with the target. Fixed mapping: not_malicious to ALLOW, suspicious to WARN, malicious to BLOCK. */
    public Action getAction() {
        return action;
    }

    /** "url" or "ip". */
    public String getMode() {
        return mode;
    }

    /** Reason codes, kept as plain strings so a new code doesn't break parsing. */
    public List<String> getReasons() {
        return reasons;
    }

    /** Where a shortened link resolved to, or null if no redirect was followed. */
    public String getFinalUrl() {
        return finalUrl;
    }

    public boolean isCached() {
        return cached;
    }

    /** Server-side evaluation time. At or above 180 the deadline was hit and the result is best-effort. */
    public int getExecutionTimeMs() {
        return executionTimeMs;
    }

    /** "sandbox" or "production", derived from the key's plan. */
    public String getEnvironment() {
        return environment;
    }

    /** False on the free sandbox plan; treat those results as integration-test output only. */
    public boolean isLicensedForProduction() {
        return licensedForProduction;
    }

    public String getRequestId() {
        return requestId;
    }

    /** Recently associated hosts (IP mode only); empty otherwise. */
    public List<RelatedHost> getRelated() {
        return related;
    }

    /** True only for {@link Action#BLOCK}. WARN is neither blocked nor safe — surface it to the user. */
    public boolean shouldBlock() {
        return action == Action.BLOCK;
    }

    /** True only for {@link Action#ALLOW}. WARN is neither blocked nor safe — surface it to the user. */
    public boolean isSafe() {
        return action == Action.ALLOW;
    }

    @Override
    public String toString() {
        return "CheckResult{verdict=" + verdict + ", action=" + action + ", mode=" + mode
                + ", reasons=" + reasons + ", finalUrl=" + finalUrl + ", cached=" + cached
                + ", executionTimeMs=" + executionTimeMs + ", environment=" + environment
                + ", licensedForProduction=" + licensedForProduction + ", requestId=" + requestId
                + ", related=" + related + "}";
    }
}
