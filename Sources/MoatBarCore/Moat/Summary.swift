import Foundation

/// Totals for a time window: `openmoat report --since <window> --format json`.
/// Shape: openmoat `crates/openmoat-audit/src/query.rs` (`Summary`).
public struct Summary: Codable, Equatable {
    public var sinceMs: Int64
    public var total: Int
    public var allowed: Int
    public var deferred: Int
    public var asked: Int
    public var denied: Int
    public var sessions: Int
    /// Events per host id.
    public var byHost: [String: Int]
    /// Rules that decided an ask or a deny, most frequent first.
    public var topRules: [RuleCount]
    /// Distinct clock hours with at least one event.
    public var activeHours: Int

    /// serde writes a `(String, u64)` tuple as a two-element array.
    public struct RuleCount: Codable, Equatable {
        public var rule: String
        public var count: Int

        public init(rule: String, count: Int) {
            self.rule = rule
            self.count = count
        }

        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            self.rule = try c.decode(String.self)
            self.count = try c.decode(Int.self)
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(self.rule)
            try c.encode(self.count)
        }
    }

    enum CodingKeys: String, CodingKey {
        case sinceMs = "since_ms"
        case total
        case allowed
        case deferred
        case asked
        case denied
        case sessions
        case byHost = "by_host"
        case topRules = "top_rules"
        case activeHours = "active_hours"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sinceMs = try c.decode(Int64.self, forKey: .sinceMs)
        self.total = try c.decode(Int.self, forKey: .total)
        self.allowed = try c.decode(Int.self, forKey: .allowed)
        // Older moat builds had no `defer` verdict.
        self.deferred = try c.decodeIfPresent(Int.self, forKey: .deferred) ?? 0
        self.asked = try c.decode(Int.self, forKey: .asked)
        self.denied = try c.decode(Int.self, forKey: .denied)
        self.sessions = try c.decode(Int.self, forKey: .sessions)
        self.byHost = try c.decodeIfPresent([String: Int].self, forKey: .byHost) ?? [:]
        self.topRules = try c.decodeIfPresent([RuleCount].self, forKey: .topRules) ?? []
        self.activeHours = try c.decodeIfPresent(Int.self, forKey: .activeHours) ?? 0
    }
}
