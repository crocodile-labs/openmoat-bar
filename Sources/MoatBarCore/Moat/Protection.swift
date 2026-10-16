import Foundation

// `moat status --format json`. Shape: openmoat `crates/openmoat-cli/src/protection.rs`.

/// How much of the policy is enforced for one agent.
public enum Level: String, Codable, Equatable {
    case hookAndOsSandbox = "hook-and-os-sandbox"
    case hookOnly = "hook-only"
    case notProtected = "not-protected"
    case notSetUp = "not-set-up"
    case notFound = "not-found"
    /// A level a newer moat added. Never shown as protected.
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Level(rawValue: raw) ?? .unknown
    }

    /// Whether the hook applies the policy to the agent's calls.
    public var isHooked: Bool {
        self == .hookAndOsSandbox || self == .hookOnly
    }

    /// Plain words for the menu.
    public var label: String {
        switch self {
        case .hookAndOsSandbox: return "Hook + sandbox"
        case .hookOnly: return "Hook only"
        case .notProtected: return "Not protected"
        case .notSetUp: return "Not set up"
        case .notFound: return "Not installed"
        case .unknown: return "Unknown"
        }
    }
}

/// One agent's protection: `agents[]` in `moat status --format json`.
public struct Protection: Codable, Equatable {
    /// Host id: `claude-code`, `codex`, `cursor`.
    public var host: String
    /// Display name: `Claude Code`.
    public var name: String
    public var level: Level
    /// Why the level is `hook-only` or `not-protected`.
    public var reason: String?
    /// What the hook and sandbox never cover for this agent.
    public var gaps: String

    public init(host: String, name: String, level: Level, reason: String? = nil, gaps: String = "") {
        self.host = host
        self.name = name
        self.level = level
        self.reason = reason
        self.gaps = gaps
    }
}

/// The whole `moat status --format json` document.
public struct StatusReport: Codable, Equatable {
    public var agents: [Protection]

    public init(agents: [Protection]) {
        self.agents = agents
    }
}
