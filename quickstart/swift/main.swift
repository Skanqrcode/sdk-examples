// Quickstart: call POST /v1/check directly with URLSession + async/await.
// No SDK abstraction — see ../../sdk/swift for the installable package.
//
// Run: SKANQRCODE_API_KEY=lure_test_... swift main.swift

import Foundation

struct CheckRequest: Encodable {
    let target: String
}

struct CheckResponse: Decodable {
    let verdict: String
    let mode: String
    let score: Int
    let reasons: [String]
    let cached: Bool
    let partial: Bool
    let requestId: String
}

struct APIErrorBody: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
        let requestId: String
    }
    let error: Detail
}

struct APIError: Error, CustomStringConvertible {
    let code: String
    let message: String
    let requestId: String
    let httpStatus: Int

    var description: String {
        "SkanQRCode API error [\(httpStatus) \(code)]: \(message) (requestId: \(requestId))"
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
        let body = try JSONDecoder().decode(APIErrorBody.self, from: data)
        throw APIError(
            code: body.error.code,
            message: body.error.message,
            requestId: body.error.requestId,
            httpStatus: httpResponse.statusCode
        )
    }

    return try JSONDecoder().decode(CheckResponse.self, from: data)
}

do {
    let result = try await checkURL(target)
    print("target:    \(target)")
    print("verdict:   \(result.verdict)")
    print("mode:      \(result.mode)")
    print("score:     \(result.score)")
    print("reasons:   \(result.reasons)")
    print("cached:    \(result.cached)")
    print("partial:   \(result.partial)")
    print("requestId: \(result.requestId)")

    if result.verdict == "malicious" {
        exit(2)
    }
} catch let error as APIError {
    print(error.description)
    exit(1)
} catch {
    print("Request failed: \(error)")
    exit(1)
}
