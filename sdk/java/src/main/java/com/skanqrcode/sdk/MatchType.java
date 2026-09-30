package com.skanqrcode.sdk;

/** What an allow-list / block-list entry matches. */
public enum MatchType {
    URL("url"),
    HOST("host"),
    DOMAIN("domain"),
    IP("ip");

    private final String wireValue;

    MatchType(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static MatchType fromWireValue(String value) {
        for (MatchType t : values()) {
            if (t.wireValue.equals(value)) {
                return t;
            }
        }
        throw new IllegalArgumentException("Unknown match type: " + value);
    }
}
