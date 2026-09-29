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
            String code = extractString(response.body(), "code");
            String message = extractString(response.body(), "message");
            String requestId = extractString(response.body(), "requestId");
            System.err.println("SkanQRCode error [" + code + "]: " + message + " (requestId=" + requestId + ")");
            return;
        }

        String verdict = extractString(response.body(), "verdict");
        Integer score = extractNumber(response.body(), "score");
        Boolean cached = extractBoolean(response.body(), "cached");
        Boolean partial = extractBoolean(response.body(), "partial");
        String requestId = extractString(response.body(), "requestId");

        System.out.println("verdict=" + verdict + " score=" + score + " cached=" + cached
                + " partial=" + partial + " requestId=" + requestId);

        switch (verdict) {
            case "malicious":
                System.out.println("BLOCK: do not open " + target);
                break;
            case "suspicious":
                System.out.println("WARN: confirm with the user before opening " + target);
                break;
            case "not_malicious":
                System.out.println("PROCEED: safe to open " + target);
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
