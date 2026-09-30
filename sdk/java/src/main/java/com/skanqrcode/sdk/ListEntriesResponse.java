package com.skanqrcode.sdk;

import java.util.List;

public final class ListEntriesResponse {
    private final List<ListEntry> entries;
    private final String nextCursor;

    public ListEntriesResponse(List<ListEntry> entries, String nextCursor) {
        this.entries = entries;
        this.nextCursor = nextCursor;
    }

    /** Newest first. */
    public List<ListEntry> getEntries() {
        return entries;
    }

    /** Pass to the next list call for the following page; null on the last page. */
    public String getNextCursor() {
        return nextCursor;
    }
}
