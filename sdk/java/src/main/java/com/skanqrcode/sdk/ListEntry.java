package com.skanqrcode.sdk;

public final class ListEntry {
    private final String id;
    private final MatchType matchType;
    private final String value;
    private final String createdAt;

    public ListEntry(String id, MatchType matchType, String value, String createdAt) {
        this.id = id;
        this.matchType = matchType;
        this.value = value;
        this.createdAt = createdAt;
    }

    public String getId() {
        return id;
    }

    public MatchType getMatchType() {
        return matchType;
    }

    /** For url entries only the registrable domain and a short hash hint are returned. */
    public String getValue() {
        return value;
    }

    /** RFC 3339, UTC. */
    public String getCreatedAt() {
        return createdAt;
    }

    @Override
    public String toString() {
        return "ListEntry{id=" + id + ", matchType=" + matchType + ", value=" + value
                + ", createdAt=" + createdAt + "}";
    }
}
