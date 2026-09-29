package com.skanqrcode.sdk;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
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

    public CheckResult checkUrl(String target) throws SkanQRCodeException, IOException, InterruptedException {
        JSONObject requestBody = new JSONObject().put("target", target);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/v1/check"))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestBody.toString()))
                .build();

        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        JSONObject body = parseOrThrow(response);

        List<String> reasons = new ArrayList<>();
        JSONArray reasonsArray = body.getJSONArray("reasons");
        for (int i = 0; i < reasonsArray.length(); i++) {
            reasons.add(reasonsArray.getString(i));
        }

        return new CheckResult(
                Verdict.fromWireValue(body.getString("verdict")),
                body.getString("mode"),
                body.getInt("score"),
                reasons,
                body.getBoolean("cached"),
                body.getBoolean("partial"),
                body.getString("requestId")
        );
    }

    public UsageResponse getUsage(Instant from, Instant to) throws SkanQRCodeException, IOException, InterruptedException {
        String query = "from=" + URLEncoder.encode(from.toString(), StandardCharsets.UTF_8)
                + "&to=" + URLEncoder.encode(to.toString(), StandardCharsets.UTF_8);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(baseUrl + "/v1/usage?" + query))
                .timeout(Duration.ofMillis(timeoutMs))
                .header("Authorization", "Bearer " + apiKey)
                .GET()
                .build();

        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        JSONObject body = parseOrThrow(response);

        List<UsageHour> hours = new ArrayList<>();
        JSONArray hoursArray = body.getJSONArray("hours");
        for (int i = 0; i < hoursArray.length(); i++) {
            JSONObject h = hoursArray.getJSONObject(i);
            hours.add(new UsageHour(
                    h.getString("hour"),
                    h.getString("mode"),
                    h.getInt("total"),
                    h.getInt("malicious"),
                    h.getInt("suspicious"),
                    h.getInt("notMalicious"),
                    h.getInt("cached"),
                    h.getInt("partial")
            ));
        }

        return new UsageResponse(
                body.getString("tenantId"),
                body.getString("from"),
                body.getString("to"),
                hours
        );
    }

    private JSONObject parseOrThrow(HttpResponse<String> response) throws SkanQRCodeException {
        int status = response.statusCode();
        JSONObject json = new JSONObject(response.body());
        if (status >= 200 && status < 300) {
            return json;
        }
        JSONObject error = json.optJSONObject("error");
        String code = error != null ? error.optString("code", "unknown_error") : "unknown_error";
        String message = error != null ? error.optString("message", response.body()) : response.body();
        String requestId = error != null ? error.optString("requestId", null) : null;
        throw new SkanQRCodeException(code, message, requestId, status);
    }
}
