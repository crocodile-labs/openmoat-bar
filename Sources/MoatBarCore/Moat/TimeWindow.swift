import Foundation

/// A time window moat understands in `--since`.
public enum TimeWindow: String, CaseIterable, Identifiable {
    case today
    case sevenDays = "7d"
    case thirtyDays = "30d"

    public var id: String {
        self.rawValue
    }

    public var title: String {
        switch self {
        case .today: return "Today"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        }
    }
}
