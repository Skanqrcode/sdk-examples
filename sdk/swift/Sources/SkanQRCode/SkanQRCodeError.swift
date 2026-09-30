import Foundation

public struct SkanQRCodeError: Error, Sendable {
    /// Machine-readable code — branch on this, never on `message`. See `SkanQRCodeError.Code`.
    /// Kept as a string so a code added in a later API version doesn't break decoding.
    public let code: String
    public let message: String
    /// From the error body, falling back to the `X-Request-Id` header; `nil` if neither is present.
    public let requestId: String?
    public let httpStatus: Int
    /// Seconds from the `Retry-After` header (429s); `nil` if absent.
    public let retryAfter: Int?

    /// The documented error codes (a closed set).
    public enum Code {
        public static let invalidRequest = "invalid_request"
        public static let unauthorized = "unauthorized"
        public static let forbidden = "forbidden"
        public static let notFound = "not_found"
        public static let planFeatureUnavailable = "plan_feature_unavailable"
        public static let paymentRequired = "payment_required"
        public static let rateLimited = "rate_limited"
        public static let quotaExceeded = "quota_exceeded"
        public static let authUnavailable = "auth_unavailable"
        public static let `internal` = "internal"
    }

    private struct Body: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
            let requestId: String?
        }
        let error: Detail
    }

    /// Never throws: if the body isn't the documented JSON (e.g. HTML from a proxy's 502), this
    /// yields a synthetic `internal` error carrying the HTTP status.
    init(data: Data, response: HTTPURLResponse) {
        let headerRequestId = response.value(forHTTPHeaderField: "X-Request-Id")
        self.httpStatus = response.statusCode
        self.retryAfter = Self.parseRetryAfter(response.value(forHTTPHeaderField: "Retry-After"))
        if let body = try? JSONDecoder().decode(Body.self, from: data) {
            self.code = body.error.code
            self.message = body.error.message
            self.requestId = body.error.requestId ?? headerRequestId
        } else {
            self.code = Code.internal
            self.message = "Unexpected HTTP \(response.statusCode) response (\(HTTPURLResponse.localizedString(forStatusCode: response.statusCode)))"
            self.requestId = headerRequestId
        }
    }

    private static func parseRetryAfter(_ value: String?) -> Int? {
        guard let value = value?.trimmingCharacters(in: .whitespaces) else { return nil }
        if let seconds = Int(value) { return seconds }
        if let seconds = Double(value) { return Int(seconds.rounded(.up)) }
        return nil // HTTP-date form isn't used by this API
    }
}

extension SkanQRCodeError: LocalizedError {
    public var errorDescription: String? {
        "SkanQRCode API error [\(httpStatus) \(code)]: \(message) (requestId: \(requestId ?? "none"))"
    }
}

extension SkanQRCodeError {
    /// `true` when a caller may retry: `rate_limited` (after `retryAfter`), `auth_unavailable`
    /// (shortly) and 5xx (with backoff). `quota_exceeded` is also a 429 but won't clear until the
    /// quota resets or the plan changes, so it is not retryable. The SDK never retries itself.
    public var isRetryable: Bool {
        code == Code.rateLimited || code == Code.authUnavailable || httpStatus >= 500
    }
}
