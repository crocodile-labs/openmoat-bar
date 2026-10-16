import Foundation

/// What the Activity window shows: one agent or all, one verdict or all,
/// optionally one rule, newest first.
public struct ActivityFilter: Equatable {
    public var host: String?
    public var verdict: Verdict?
    public var rule: String?

    public init(host: String? = nil, verdict: Verdict? = .deny, rule: String? = nil) {
        self.host = host
        self.verdict = verdict
        self.rule = rule
    }

    /// Matching events, newest first.
    public func apply(_ events: [Event]) -> [Event] {
        events.reversed().filter { event in
            (self.host == nil || event.host == self.host)
                && (self.verdict == nil || event.verdict == self.verdict)
                && (self.rule == nil || event.rules.contains(self.rule ?? ""))
        }
    }
}
