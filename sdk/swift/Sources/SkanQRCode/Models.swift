import Foundation

// Enums that come back from the server fall back to `.unknown` instead of failing to decode, so
// a value added in a later API version doesn't break an older SDK. `unknown` is never `isSafe`
// and never `shouldBlock` — callers should treat it like `warn` (surface it, don't auto-open).

public enum Verdict: String, Codable, Sendable {
    case malicious
    case suspicious
    case notMalicious = "not_malicious"
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Verdict(rawValue: raw) ?? .unknown
    }
}

/// What the caller should do with the target. Fixed server-side mapping:
/// `not_malicious` -> `allow`, `suspicious` -> `warn`, `malicious` -> `block`. Branch on this.
public enum Action: String, Codable, Sendable {
    case allow
    case warn
    case block
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Action(rawValue: raw) ?? .unknown
    }
}

public enum Mode: String, Codable, Sendable {
    case url
    case ip
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Mode(rawValue: raw) ?? .unknown
    }
}

/// Derived from the key's plan, never from the request. (Named `CheckEnvironment` so it doesn't
/// collide with SwiftUI's `Environment` property wrapper.)
public enum CheckEnvironment: String, Codable, Sendable {
    case sandbox
    case production
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CheckEnvironment(rawValue: raw) ?? .unknown
    }
}

/// How an allow-list/block-list entry matches. A closed set that is also sent in requests, so
/// an unrecognized value from the server fails decoding rather than becoming a fake case.
public enum MatchType: String, Codable, Sendable {
    /// Exact URL.
    case url
    /// Hostname.
    case host
    /// Registrable domain, including subdomains.
    case domain
    case ip
}

public enum PlanId: String, Codable, Sendable {
    case pro
    case business
}

/// A recently associated host. Only returned in IP mode.
public struct RelatedHost: Codable, Sendable {
    public let host: String
    public let verdict: Verdict
}

public struct CheckResult: Codable, Sendable {
    public let verdict: Verdict
    public let action: Action
    public let mode: Mode
    /// Reason codes (e.g. `KNOWN_PHISHING_MATCH`) — kept as plain strings so a new code doesn't
    /// break decoding. See docs/api-contract.md for the current set.
    public let reasons: [String]
    /// Where a shortened link resolved to, if a redirect was followed.
    public let finalUrl: String?
    public let cached: Bool
    /// Server-side evaluation time in milliseconds.
    public let executionTimeMs: Int
    public let environment: CheckEnvironment
    /// `false` on the free sandbox plan — use those results for integration testing only.
    public let licensedForProduction: Bool
    public let requestId: String
    /// IP mode only: recently associated hosts, most recent first.
    public let related: [RelatedHost]?

    /// `true` only when the server says `block`.
    public var shouldBlock: Bool { action == .block }
    /// `true` only when the server says `allow`. `warn` is neither safe nor blocked.
    public var isSafe: Bool { action == .allow }
}

/// `GET /v1/usage` — monthly quota summary. Lags real time by up to about an hour.
public struct UsageResponse: Codable, Sendable {
    public let tenantId: String
    public let month: String
    public let monthlyQuota: Int
    public let totalRequests: Int
    public let availableRequests: Int
}

public struct UsageHour: Codable, Sendable {
    public let hour: Date
    public let mode: Mode
    public let total: Int
    /// `total / hourlyCapacity * 100`, one decimal. Near 100 means that hour ran at the rate limit.
    public let capacityUsedPercent: Double
    public let blockedRpm: Int
    public let blockedQuota: Int
    public let malicious: Int
    public let suspicious: Int
    public let notMalicious: Int
    public let cached: Int
}

/// `GET /v1/usage/hourly` — hour-by-hour usage with per-minute rate-limit utilization.
public struct UsageHourlyResponse: Codable, Sendable {
    public let tenantId: String
    public let month: String
    public let rpmLimit: Int
    /// `rpmLimit * 60`. A reading aid only — limits are enforced per minute.
    public let hourlyCapacity: Int
    public let hours: [UsageHour]
}

public struct ListEntry: Codable, Sendable {
    public let id: String
    public let matchType: MatchType
    public let value: String
    public let createdAt: Date
}

public struct ListEntriesPage: Codable, Sendable {
    public let entries: [ListEntry]
    /// Pass to the next call as `cursor`; `nil` on the last page.
    public let nextCursor: String?
}

/// Returned by the billing operations: a URL to hand to a person.
public struct SessionURL: Codable, Sendable {
    public let url: String
}

public struct HealthResponse: Codable, Sendable {
    public let status: String
}
