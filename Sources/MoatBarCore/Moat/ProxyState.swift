import Foundation

/// `moat proxy status --format json` (macOS and Linux; Windows has no proxy
/// service yet). Shape: openmoat `crates/openmoat-cli/src/commands/service.rs`.
///
///     {"path": "...", "service": "launchd user agent", "state": {"state": "running"}}
public struct ProxyReport: Decodable, Equatable {
    public var path: String?
    public var service: String?
    public var state: ProxyState
}

/// The proxy service's state.
public enum ProxyState: Equatable {
    case notInstalled
    case stopped
    case running
    /// The proxy exited because a watched file changed.
    case driftBlocked
    case crashlooping
    case unknown(details: String)

    public var isRunning: Bool {
        self == .running
    }

    /// Plain words for the menu.
    public var label: String {
        switch self {
        case .notInstalled: return "Not installed"
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .driftBlocked: return "Stopped after a watched file changed"
        case .crashlooping: return "Keeps crashing"
        case let .unknown(details): return details
        }
    }
}

// MARK: - ProxyState + Decodable

extension ProxyState: Decodable {
    private enum CodingKeys: String, CodingKey {
        case state
        case details
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .state) {
        case "not-installed": self = .notInstalled
        case "stopped": self = .stopped
        case "running": self = .running
        case "drift-blocked": self = .driftBlocked
        case "crashlooping": self = .crashlooping
        case let other: self = .unknown(details: (try? c.decode(String.self, forKey: .details)) ?? other)
        }
    }
}
