import Foundation

public struct SkanQRCodeError: Error, Codable, Sendable {
    public let code: String
    public let message: String
    public let requestId: String
    public let httpStatus: Int

    private struct Body: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
            let requestId: String
        }
        let error: Detail
    }

    init(decoding data: Data, httpStatus: Int) throws {
        let body = try JSONDecoder().decode(Body.self, from: data)
        self.code = body.error.code
        self.message = body.error.message
        self.requestId = body.error.requestId
        self.httpStatus = httpStatus
    }
}

extension SkanQRCodeError: LocalizedError {
    public var errorDescription: String? {
        "SkanQRCode API error [\(httpStatus) \(code)]: \(message) (requestId: \(requestId))"
    }
}

extension SkanQRCodeError {
    public var isRetryable: Bool {
        httpStatus >= 500 || code == "rate_limited"
    }
}
