import Foundation

/// moat's decision for one call. Shape: openmoat `crates/openmoat-core/src/verdict.rs`.
public enum Verdict: String, Codable, CaseIterable {
    case deny
    case ask
    case deferred = "defer"
    case allow

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // A verdict a newer moat added counts as left to the agent: never as
        // allowed or blocked.
        self = Verdict(rawValue: raw) ?? .deferred
    }

    /// The name the menu uses.
    public var title: String {
        switch self {
        case .deny: return "Blocked"
        case .ask: return "Asked"
        case .deferred: return "Left to your agent"
        case .allow: return "Allowed"
        }
    }

    /// One line under the name.
    public var subtitle: String {
        switch self {
        case .deny: return "Stopped, with the rule and the reason"
        case .ask: return "OpenMoat asked a person"
        case .deferred: return "No rule: the agent's own prompt decided"
        case .allow: return "Normal work ran"
        }
    }
}
