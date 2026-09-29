import Foundation

public struct SkanQRCodeClient: Sendable {
    private let apiKey: String
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.skanqrcode.com")!,
        timeout: TimeInterval = 5.0
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.session = URLSession(configuration: .default)
    }

    public func checkURL(_ target: String) async throws -> CheckResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/check"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONEncoder().encode(["target": target])

        let (data, response) = try await send(request)
        return try decode(CheckResult.self, from: data, response: response)
    }

    public func usage(from: Date, to: Date) async throws -> UsageResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/v1/usage"),
            resolvingAgainstBaseURL: false
        )!
        let formatter = ISO8601DateFormatter()
        components.queryItems = [
            URLQueryItem(name: "from", value: formatter.string(from: from)),
            URLQueryItem(name: "to", value: formatter.string(from: to)),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        let (data, response) = try await send(request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decode(UsageResponse.self, from: data, response: response, decoder: decoder)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }

    private func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        response: HTTPURLResponse,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard (200...299).contains(response.statusCode) else {
            throw try SkanQRCodeError(decoding: data, httpStatus: response.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}
