// Quickstart: call POST /v1/check directly with URLSession + async/await.
// No SDK abstraction — see ../../sdk/swift for the installable package.
//
// Run: SKANQRCODE_API_KEY=sk_test_... swift main.swift

import Foundation

struct CheckRequest: Encodable {
    let target: String
}

struct CheckResponse: Decodable {
    let verdict: String
    let action: String // allow | warn | block — branch on this
    let mode: String
    let reasons: [String]
    let cached: Bool
    let executionTimeMs: Int
    let environment: String // sandbox | production
    let requestId: String
}

struct APIErrorBody: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
        let requestId: String?
    }
    let error: Detail
}

struct APIError: Error, CustomStringConvertible {
    let code: String
    let message: String
    let requestId: String?
    let httpStatus: Int
    let retryAfter: String? // Retry-After header (seconds), set on 429s

    var description: String {
        var text = "SkanQRCode API error [\(httpStatus) \(code)]: \(message) (requestId: \(requestId ?? "none"))"
        if let retryAfter { text += " — retry after \(retryAfter)s" }
        return text
    }
}

guard let apiKey = ProcessInfo.processInfo.environment["SKANQRCODE_API_KEY"], !apiKey.isEmpty else {
    print("Set SKANQRCODE_API_KEY in your environment first.")
    exit(1)
}

let baseURL = URL(string: "https://api.skanqrcode.com")!
let target = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "https://example.com/login"

func checkURL(_ target: String) async throws -> CheckResponse {
    var request = URLRequest(url: baseURL.appendingPathComponent("/v1/check"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(CheckRequest(target: target))
    request.timeoutInterval = 5.0

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        // A proxy's HTML 502 isn't the documented JSON: fall back to a synthetic `internal` error.
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        throw APIError(
            code: body?.error.code ?? "internal",
            message: body?.error.message ?? "Unexpected HTTP \(httpResponse.statusCode) response",
            requestId: body?.error.requestId,
            httpStatus: httpResponse.statusCode,
            retryAfter: httpResponse.value(forHTTPHeaderField: "Retry-After")
        )
    }

    return try JSONDecoder().decode(CheckResponse.self, from: data)
}

do {
    let result = try await checkURL(target)
    print("target:    \(target)")
    print("verdict:   \(result.verdict)")
    print("action:    \(result.action)")
    print("mode:      \(result.mode)")
    print("reasons:   \(result.reasons)")
    print("cached:    \(result.cached)")
    print("time:      \(result.executionTimeMs) ms")
    print("env:       \(result.environment)")
    print("requestId: \(result.requestId)")

    if result.action == "block" {
        exit(2)
    }
} catch let error as APIError {
    print(error.description)
    switch error.code {
    case "unauthorized", "payment_required", "quota_exceeded":
        print("Not retryable: check your API key, billing status or monthly quota.")
    case "rate_limited", "auth_unavailable", "internal":
        print("Retryable: wait (see Retry-After) and try again.")
    default:
        break // invalid_request, forbidden, not_found, plan_feature_unavailable
    }
    exit(1)
} catch {
    print("Request failed: \(error)")
    exit(1)
}
