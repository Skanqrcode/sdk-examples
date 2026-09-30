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

    // MARK: Check

    /// Classifies a URL or IPv4/IPv6 address. Consumes one quota unit per successful call.
    /// `userId` is an opaque end-user identifier that enables per-user result caching.
    public func checkURL(_ target: String, userId: String? = nil) async throws -> CheckResult {
        struct Body: Encodable {
            let target: String
            let userId: String? // omitted from the JSON when nil
        }
        let request = try makeRequest("POST", "/v1/check", body: Body(target: target, userId: userId))
        return try await perform(request)
    }

    // MARK: Usage

    /// Monthly quota summary. `month` is `YYYY-MM` (UTC); defaults to the current month.
    public func getUsage(month: String? = nil) async throws -> UsageResponse {
        try await perform(try makeRequest("GET", "/v1/usage", query: monthQuery(month)))
    }

    /// Hour-by-hour usage with rate-limit utilization. `month` is `YYYY-MM` (UTC).
    public func getUsageHourly(month: String? = nil) async throws -> UsageHourlyResponse {
        try await perform(try makeRequest("GET", "/v1/usage/hourly", query: monthQuery(month)))
    }

    // MARK: Allow list (Pro & Business plans) and block list (every plan)

    /// Newest first. `limit` is 1-500 (default 100); pass the previous page's `nextCursor` as `cursor`.
    public func listAllowList(limit: Int? = nil, cursor: String? = nil) async throws -> ListEntriesPage {
        try await list("/v1/allow-list", limit: limit, cursor: cursor)
    }

    /// Needs an `admin`-scope key. Adding is idempotent: 201 (created) and 200 (already existed) both succeed.
    public func addAllowListEntry(matchType: MatchType, value: String) async throws -> ListEntry {
        try await add("/v1/allow-list", matchType: matchType, value: value)
    }

    /// Needs an `admin`-scope key. Throws `not_found` if the entry doesn't exist for this tenant.
    public func deleteAllowListEntry(_ entryId: String) async throws {
        try await delete("/v1/allow-list", entryId: entryId)
    }

    public func listBlockList(limit: Int? = nil, cursor: String? = nil) async throws -> ListEntriesPage {
        try await list("/v1/block-list", limit: limit, cursor: cursor)
    }

    /// Needs an `admin`-scope key. Adding is idempotent: 201 (created) and 200 (already existed) both succeed.
    public func addBlockListEntry(matchType: MatchType, value: String) async throws -> ListEntry {
        try await add("/v1/block-list", matchType: matchType, value: value)
    }

    /// Needs an `admin`-scope key. Throws `not_found` if the entry doesn't exist for this tenant.
    public func deleteBlockListEntry(_ entryId: String) async throws {
        try await delete("/v1/block-list", entryId: entryId)
    }

    // MARK: Billing (human-in-the-loop, admin scope)

    /// Human-in-the-loop, `admin` scope. Returns a checkout URL to hand to a person — an
    /// autonomous agent must never complete checkout itself. `turnstileToken` is a bot-challenge
    /// token minted by the checkout-start page, so this is only callable from a flow with a real
    /// browser in the loop.
    public func createCheckoutSession(planId: PlanId, turnstileToken: String) async throws -> SessionURL {
        struct Body: Encodable {
            let planId: PlanId
            let turnstileToken: String
        }
        let request = try makeRequest(
            "POST", "/v1/billing/checkout",
            body: Body(planId: planId, turnstileToken: turnstileToken)
        )
        return try await perform(request)
    }

    /// Human-in-the-loop, `admin` scope. Returns a billing-portal URL to hand to a person.
    public func createPortalSession() async throws -> SessionURL {
        try await perform(try makeRequest("POST", "/v1/billing/portal"))
    }

    // MARK: Health

    /// Liveness only (no API key needed) — says nothing about the freshness of verdict data.
    public func getHealth() async throws -> HealthResponse {
        try await perform(try makeRequest("GET", "/health", authenticated: false))
    }

    // MARK: Plumbing

    private func list(_ path: String, limit: Int?, cursor: String?) async throws -> ListEntriesPage {
        var query: [URLQueryItem] = []
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await perform(try makeRequest("GET", path, query: query))
    }

    private func add(_ path: String, matchType: MatchType, value: String) async throws -> ListEntry {
        struct Body: Encodable {
            let matchType: MatchType
            let value: String
        }
        let request = try makeRequest("POST", path, body: Body(matchType: matchType, value: value))
        return try await perform(request) // 200 and 201 are both success
    }

    private func delete(_ path: String, entryId: String) async throws {
        var segment = CharacterSet.urlPathAllowed
        segment.remove(charactersIn: "/")
        let encoded = entryId.addingPercentEncoding(withAllowedCharacters: segment) ?? entryId
        let request = try makeRequest("DELETE", "\(path)/\(encoded)", encodedPath: true)
        _ = try await send(request) // 204: no body to parse
    }

    private func monthQuery(_ month: String?) -> [URLQueryItem] {
        month.map { [URLQueryItem(name: "month", value: $0)] } ?? []
    }

    private func makeRequest(
        _ method: String,
        _ path: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        authenticated: Bool = true,
        encodedPath: Bool = false
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = components.percentEncodedPath
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.percentEncodedPath = basePath + (encodedPath ? path : path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" alone, which servers may read as a space (e.g. in a cursor).
            components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        if authenticated {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    /// Sends the request and returns the body of a 2xx response; any other status throws `SkanQRCodeError`.
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw SkanQRCodeError(data: data, response: httpResponse)
        }
        return data
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        try Self.decoder.decode(T.self, from: try await send(request))
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        // Timestamps are ISO 8601 UTC; accept both with and without fractional seconds.
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = plain.date(from: raw) ?? fractional.date(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Invalid ISO 8601 date: \(raw)")
                )
            }
            return date
        }
        return decoder
    }
}
