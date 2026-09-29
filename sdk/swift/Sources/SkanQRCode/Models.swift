import Foundation

public enum Verdict: String, Codable, Sendable {
    case malicious
    case suspicious
    case notMalicious = "not_malicious"
}

public enum Mode: String, Codable, Sendable {
    case url
    case ip
}

public enum Recommendation: Sendable {
    case proceed
    case warn
    case block
}

public struct CheckResult: Codable, Sendable {
    public let verdict: Verdict
    public let mode: Mode
    public let score: Int
    public let reasons: [String]
    public let cached: Bool
    public let partial: Bool
    public let requestId: String

    enum CodingKeys: String, CodingKey {
        case verdict, mode, score, reasons, cached, partial
        case requestId = "requestId" // already camelCase on the wire; explicit for clarity
    }

    public var recommendation: Recommendation {
        switch verdict {
        case .malicious: return .block
        case .suspicious: return .warn
        case .notMalicious: return .proceed
        }
    }

    public var shouldBlock: Bool { recommendation == .block }
    public var isSafe: Bool { recommendation == .proceed }
}

public struct UsageHour: Codable, Sendable {
    public let hour: Date
    public let mode: Mode
    public let total: Int
    public let malicious: Int
    public let suspicious: Int
    public let notMalicious: Int
    public let cached: Int
    public let partial: Int
}

public struct UsageResponse: Codable, Sendable {
    public let tenantId: String
    public let from: Date
    public let to: Date
    public let hours: [UsageHour]
}
