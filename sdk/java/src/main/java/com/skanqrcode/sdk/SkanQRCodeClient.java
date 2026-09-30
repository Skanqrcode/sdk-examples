package com.skanqrcode.sdk;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

public final class SkanQRCodeClient {

    private final String apiKey;
    private final String baseUrl;
    private final int timeoutMs;
    private final HttpClient http;

    public SkanQRCodeClient(String apiKey) {
        this(apiKey, "https://api.skanqrcode.com", 5000);
    }

    public SkanQRCodeClient(String apiKey, String baseUrl, int timeoutMs) {
        this.apiKey = apiKey;
        this.baseUrl = baseUrl;
        this.timeoutMs = timeoutMs;
        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofMillis(timeoutMs))
                .build();
    }

    /** Classifies a URL or IP address. Consumes one unit of monthly quota. */
    public CheckResult checkUrl(String target) throws SkanQRCodeException, IOException, InterruptedException {
        return checkUrl(target, null);
    }

    /**
     * Classifies a URL or IP address. {@code userId} is an optional opaque end-user identifier
     * that enables per-user result caching; it is only sent when non-null.
     */
    public CheckResult checkUrl(String target, String userId) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject requestBody = new JSONObject().put("target", target);
        if (userId != null) {
            requestBody.put("userId", userId);
        }

        JSONObject body = parseOrThrow(send("POST", "/v1/check", requestBody, true));
        try {
            List<String> reasons = new ArrayList<>();
            JSONArray reasonsArray = body.getJSONArray("reasons");
            for (int i = 0; i < reasonsArray.length(); i++) {
                reasons.add(reasonsArray.getString(i));
            }

            List<RelatedHost> related = new ArrayList<>();
            JSONArray relatedArray = body.optJSONArray("related");
            if (relatedArray != null) {
                for (int i = 0; i < relatedArray.length(); i++) {
                    JSONObject r = relatedArray.getJSONObject(i);
                    related.add(new RelatedHost(r.getString("host"), Verdict.fromWireValue(r.getString("verdict"))));
                }
            }

            return new CheckResult(
                    Verdict.fromWireValue(body.getString("verdict")),
                    Action.fromWireValue(body.getString("action")),
                    body.getString("mode"),
                    reasons,
                    nullableString(body, "finalUrl"),
                    body.getBoolean("cached"),
                    body.getInt("executionTimeMs"),
                    body.getString("environment"),
                    body.getBoolean("licensedForProduction"),
                    body.getString("requestId"),
                    related
            );
        } catch (JSONException | IllegalArgumentException e) {
            throw malformed(e);
        }
    }

    /** Monthly usage summary for the current UTC month. */
    public UsageResponse getUsage() throws SkanQRCodeException, IOException, InterruptedException {
        return getUsage(null);
    }

    /** Monthly usage summary. {@code month} is YYYY-MM (UTC); null means the current month. */
    public UsageResponse getUsage(String month) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject body = parseOrThrow(send("GET", "/v1/usage" + query("month", month), null, true));
        try {
            return new UsageResponse(
                    body.getString("tenantId"),
                    body.getString("month"),
                    body.getInt("monthlyQuota"),
                    body.getInt("totalRequests"),
                    body.getInt("availableRequests")
            );
        } catch (JSONException e) {
            throw malformed(e);
        }
    }

    /** Hour-by-hour usage for the current UTC month, with rate-limit utilization. */
    public HourlyUsageResponse getUsageHourly() throws SkanQRCodeException, IOException, InterruptedException {
        return getUsageHourly(null);
    }

    /** Hour-by-hour usage. {@code month} is YYYY-MM (UTC); null means the current month. */
    public HourlyUsageResponse getUsageHourly(String month) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject body = parseOrThrow(send("GET", "/v1/usage/hourly" + query("month", month), null, true));
        try {
            List<UsageHour> hours = new ArrayList<>();
            JSONArray hoursArray = body.getJSONArray("hours");
            for (int i = 0; i < hoursArray.length(); i++) {
                JSONObject h = hoursArray.getJSONObject(i);
                hours.add(new UsageHour(
                        h.getString("hour"),
                        h.getString("mode"),
                        h.getInt("total"),
                        h.getDouble("capacityUsedPercent"),
                        h.getInt("blockedRpm"),
                        h.getInt("blockedQuota"),
                        h.getInt("malicious"),
                        h.getInt("suspicious"),
                        h.getInt("notMalicious"),
                        h.getInt("cached")
                ));
            }

            return new HourlyUsageResponse(
                    body.getString("tenantId"),
                    body.getString("month"),
                    body.getInt("rpmLimit"),
                    body.getInt("hourlyCapacity"),
                    hours
            );
        } catch (JSONException e) {
            throw malformed(e);
        }
    }

    /** Lists allow-list entries, newest first. Pro and Business plans only. Null limit/cursor use server defaults. */
    public ListEntriesResponse listAllowList(Integer limit, String cursor) throws SkanQRCodeException, IOException, InterruptedException {
        return listEntries("/v1/allow-list", limit, cursor);
    }

    public ListEntriesResponse listAllowList() throws SkanQRCodeException, IOException, InterruptedException {
        return listAllowList(null, null);
    }

    /** Adds an allow-list entry (idempotent). Needs an admin-scope key; Pro and Business plans only. */
    public ListEntry addAllowListEntry(MatchType matchType, String value) throws SkanQRCodeException, IOException, InterruptedException {
        return addEntry("/v1/allow-list", matchType, value);
    }

    /** Removes an allow-list entry. Needs an admin-scope key; Pro and Business plans only. */
    public void deleteAllowListEntry(String entryId) throws SkanQRCodeException, IOException, InterruptedException {
        deleteEntry("/v1/allow-list/", entryId);
    }

    /** Lists block-list entries, newest first. Every plan. Null limit/cursor use server defaults. */
    public ListEntriesResponse listBlockList(Integer limit, String cursor) throws SkanQRCodeException, IOException, InterruptedException {
        return listEntries("/v1/block-list", limit, cursor);
    }

    public ListEntriesResponse listBlockList() throws SkanQRCodeException, IOException, InterruptedException {
        return listBlockList(null, null);
    }

    /** Adds a block-list entry (idempotent). Needs an admin-scope key. */
    public ListEntry addBlockListEntry(MatchType matchType, String value) throws SkanQRCodeException, IOException, InterruptedException {
        return addEntry("/v1/block-list", matchType, value);
    }

    /** Removes a block-list entry. Needs an admin-scope key. */
    public void deleteBlockListEntry(String entryId) throws SkanQRCodeException, IOException, InterruptedException {
        deleteEntry("/v1/block-list/", entryId);
    }

    /**
     * Starts a subscription checkout. Human-in-the-loop: needs an admin-scope key and a Turnstile
     * token minted by a real browser, and the returned URL is for a person to open — an
     * autonomous agent must hand it to a human, never complete checkout itself.
     *
     * @param planId "pro" or "business"
     */
    public SessionUrlResponse createCheckoutSession(String planId, String turnstileToken) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject requestBody = new JSONObject().put("planId", planId).put("turnstileToken", turnstileToken);
        return parseSessionUrl(parseOrThrow(send("POST", "/v1/billing/checkout", requestBody, true)));
    }

    /**
     * Opens the billing portal. Human-in-the-loop: needs an admin-scope key, and the returned URL
     * is for a person to open — never something an autonomous agent should act on itself.
     */
    public SessionUrlResponse createPortalSession() throws SkanQRCodeException, IOException, InterruptedException {
        return parseSessionUrl(parseOrThrow(send("POST", "/v1/billing/portal", null, true)));
    }

    /** Liveness check. No API key needed. */
    public HealthResponse getHealth() throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject body = parseOrThrow(send("GET", "/health", null, false));
        try {
            return new HealthResponse(body.getString("status"));
        } catch (JSONException e) {
            throw malformed(e);
        }
    }

    private ListEntriesResponse listEntries(String path, Integer limit, String cursor) throws SkanQRCodeException, IOException, InterruptedException {
        String query = query("limit", limit != null ? limit.toString() : null, "cursor", cursor);
        JSONObject body = parseOrThrow(send("GET", path + query, null, true));
        try {
            List<ListEntry> entries = new ArrayList<>();
            JSONArray entriesArray = body.getJSONArray("entries");
            for (int i = 0; i < entriesArray.length(); i++) {
                entries.add(parseEntry(entriesArray.getJSONObject(i)));
            }
            return new ListEntriesResponse(entries, nullableString(body, "nextCursor"));
        } catch (JSONException | IllegalArgumentException e) {
            throw malformed(e);
        }
    }

    private ListEntry addEntry(String path, MatchType matchType, String value) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject requestBody = new JSONObject().put("matchType", matchType.wireValue()).put("value", value);
        // 201 (created) and 200 (already existed) are both success.
        JSONObject body = parseOrThrow(send("POST", path, requestBody, true));
        try {
            return parseEntry(body);
        } catch (JSONException | IllegalArgumentException e) {
            throw malformed(e);
        }
    }

    private void deleteEntry(String pathPrefix, String entryId) throws SkanQRCodeException, IOException, InterruptedException {
        // 204 has no body — only look at the status.
        HttpResponse<String> response = send("DELETE", pathPrefix + encodePathSegment(entryId), null, true);
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw toException(response);
        }
    }

    private static ListEntry parseEntry(JSONObject e) {
        return new ListEntry(
                e.getString("id"),
                MatchType.fromWireValue(e.getString("matchType")),
                e.getString("value"),
                e.getString("createdAt")
        );
    }

    private SessionUrlResponse parseSessionUrl(JSONObject body) throws SkanQRCodeException {
        try {
            return new SessionUrlResponse(body.getString("url"));
        } catch (JSONException e) {
            throw malformed(e);
        }
    }

    private HttpResponse<String> send(String method, String path, JSONObject jsonBody, boolean authenticated)
            throws IOException, InterruptedException {
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + path))
                .timeout(Duration.ofMillis(timeoutMs));
        if (authenticated) {
            builder.header("Authorization", "Bearer " + apiKey);
        }
        if (jsonBody != null) {
            builder.header("Content-Type", "application/json");
            builder.method(method, HttpRequest.BodyPublishers.ofString(jsonBody.toString()));
        } else {
            builder.method(method, HttpRequest.BodyPublishers.noBody());
        }
        return http.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private JSONObject parseOrThrow(HttpResponse<String> response) throws SkanQRCodeException {
        int status = response.statusCode();
        if (status >= 200 && status < 300) {
            try {
                return new JSONObject(response.body());
            } catch (JSONException e) {
                throw malformed(e);
            }
        }
        throw toException(response);
    }

    // Builds the typed exception for a non-2xx response. A body that isn't the documented
    // JSON (e.g. a proxy's HTML 502) becomes code "internal" with the HTTP status.
    private SkanQRCodeException toException(HttpResponse<String> response) {
        int status = response.statusCode();
        String code = ErrorCode.INTERNAL;
        String message = "HTTP " + status;
        String requestId = null;
        try {
            JSONObject error = new JSONObject(response.body()).optJSONObject("error");
            if (error != null) {
                code = error.optString("code", ErrorCode.INTERNAL);
                message = error.optString("message", message);
                requestId = error.has("requestId") && !error.isNull("requestId") ? error.optString("requestId") : null;
            }
        } catch (JSONException ignored) {
            // not JSON — keep the synthetic internal error
        }
        return new SkanQRCodeException(code, message, requestId, status, retryAfterSeconds(response));
    }

    private static Integer retryAfterSeconds(HttpResponse<String> response) {
        return response.headers().firstValue("Retry-After").map(v -> {
            try {
                return Integer.valueOf(v.trim());
            } catch (NumberFormatException e) {
                return null; // e.g. an HTTP-date form; the API sends seconds
            }
        }).orElse(null);
    }

    private static SkanQRCodeException malformed(Exception cause) {
        SkanQRCodeException e = new SkanQRCodeException(ErrorCode.INTERNAL, "Unexpected response body: " + cause.getMessage(), null, 200, null);
        e.initCause(cause);
        return e;
    }

    // org.json's optString turns JSON null into the string "null", so check explicitly.
    private static String nullableString(JSONObject obj, String key) {
        return obj.isNull(key) ? null : obj.getString(key);
    }

    // Builds "?k=v&k=v" from name/value pairs, skipping null values; "" if nothing is set.
    private static String query(String... pairs) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < pairs.length; i += 2) {
            if (pairs[i + 1] == null) {
                continue;
            }
            sb.append(sb.length() == 0 ? '?' : '&')
                    .append(pairs[i]).append('=')
                    .append(URLEncoder.encode(pairs[i + 1], StandardCharsets.UTF_8));
        }
        return sb.toString();
    }

    private static String encodePathSegment(String value) {
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
