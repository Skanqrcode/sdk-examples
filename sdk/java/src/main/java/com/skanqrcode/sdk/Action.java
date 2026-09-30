package com.skanqrcode.sdk;

/** What the caller should do with a checked target. Server-provided; branch on this. */
public enum Action {
    ALLOW("allow"),
    WARN("warn"),
    BLOCK("block");

    private final String wireValue;

    Action(String wireValue) {
        this.wireValue = wireValue;
    }

    public String wireValue() {
        return wireValue;
    }

    public static Action fromWireValue(String value) {
        for (Action a : values()) {
            if (a.wireValue.equals(value)) {
                return a;
            }
        }
        throw new IllegalArgumentException("Unknown action: " + value);
    }
}
