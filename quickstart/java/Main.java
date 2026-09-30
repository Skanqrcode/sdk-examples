import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class Main {

    private static final String BASE_URL = "https://api.skanqrcode.com";

    public static void main(String[] args) throws Exception {
        String apiKey = System.getenv("SKANQRCODE_API_KEY");
        if (apiKey == null || apiKey.isEmpty()) {
            System.err.println("Set SKANQRCODE_API_KEY to your SkanQRCode API key");
            System.exit(1);
        }

        String target = "https://example.com/login";

        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(BASE_URL + "/v1/check"))
                .timeout(Duration.ofSeconds(5))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString("{\"target\":\"" + escapeJson(target) + "\"}"))
                .build();

        HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

        if (response.statusCode() != 200) {
            // Error bodies are {"error":{"code","message","requestId"}}; a proxy may return HTML instead.
            String code = extractString(response.body(), "code");
            if (code == null) {
                code = "internal";
            }
            String message = extractString(response.body(), "message");
            String requestId = extractString(response.body(), "requestId");
            String retryAfter = response.headers().firstValue("Retry-After").orElse(null);
            System.err.println("SkanQRCode error [" + code + "] HTTP " + response.statusCode() + ": " + message
                    + " (requestId=" + requestId + ")");
            switch (code) {
                case "rate_limited":
                    System.err.println("Too many requests: retry in " + retryAfter + "s");
                    break;
                case "quota_exceeded":
                case "payment_required":
                case "unauthorized":
                    System.err.println("Configuration problem (key, plan or quota) - retrying won't help");
                    break;
                default:
                    break;
            }
            return;
        }

        String verdict = extractString(response.body(), "verdict");
        String action = extractString(response.body(), "action");
        Integer executionTimeMs = extractNumber(response.body(), "executionTimeMs");
        String environment = extractString(response.body(), "environment");
        Boolean cached = extractBoolean(response.body(), "cached");
        String requestId = extractString(response.body(), "requestId");

        System.out.println("verdict=" + verdict + " action=" + action + " executionTimeMs=" + executionTimeMs
                + " environment=" + environment + " cached=" + cached + " requestId=" + requestId);
        if ("sandbox".equals(environment)) {
            System.out.println("(sandbox key: results are for integration testing only)");
        }

        // Branch on action, not verdict. Anything unexpected is treated as "don't open".
        switch (String.valueOf(action)) {
            case "allow":
                System.out.println("ALLOW: safe to open " + target);
                break;
            case "warn":
                System.out.println("WARN: confirm with the user before opening " + target);
                break;
            default:
                System.out.println("BLOCK: do not open " + target);
                break;
        }
    }

    // Hand-rolled extraction to keep this quickstart dependency-free — it targets the one
    // fixed response shape in docs/api-contract.md. For typed (de)serialization, see sdk/java.
    private static String extractString(String json, String field) {
        Matcher m = Pattern.compile("\"" + field + "\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\"").matcher(json);
        return m.find() ? unescapeJson(m.group(1)) : null;
    }

    private static Integer extractNumber(String json, String field) {
        Matcher m = Pattern.compile("\"" + field + "\"\\s*:\\s*(-?\\d+)").matcher(json);
        return m.find() ? Integer.valueOf(m.group(1)) : null;
    }

    private static Boolean extractBoolean(String json, String field) {
        Matcher m = Pattern.compile("\"" + field + "\"\\s*:\\s*(true|false)").matcher(json);
        return m.find() ? Boolean.valueOf(m.group(1)) : null;
    }

    private static String escapeJson(String s) {
        return s.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static String unescapeJson(String s) {
        return s.replace("\\\"", "\"").replace("\\\\", "\\");
    }
}
