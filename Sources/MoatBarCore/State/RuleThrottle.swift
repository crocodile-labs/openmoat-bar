import Foundation

/// Limits block notifications to one per rule per period, so a loop that hits
/// the same rule does not flood the screen.
public struct RuleThrottle {
    public var period: TimeInterval
    private var lastSent: [String: Date] = [:]

    public init(period: TimeInterval = 600) {
        self.period = period
    }

    /// Whether a notification for `rule` may go out now; records it if so.
    public mutating func allow(_ rule: String, now: Date = Date()) -> Bool {
        if let last = self.lastSent[rule], now.timeIntervalSince(last) < self.period {
            return false
        }
        self.lastSent[rule] = now
        return true
    }
}
