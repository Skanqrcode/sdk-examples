package com.skanqrcode.sdk;

public enum Verdict {
    MALICIOUS("malicious"),
    SUSPICIOUS("suspicious"),
    NOT_MALICIOUS("not_malicious");

    private final String wireValue;

    Verdict(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static Verdict fromWireValue(String value) {
        for (Verdict v : values()) {
            if (v.wireValue.equals(value)) {
                return v;
            }
        }
        throw new IllegalArgumentException("Unknown verdict: " + value);
    }
}
