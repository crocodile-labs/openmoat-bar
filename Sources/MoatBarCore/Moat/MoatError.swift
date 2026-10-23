import Foundation

/// Why OpenMoat Bar could not read moat.
public enum MoatError: Error, Equatable {
    /// No moat binary was found.
    case notInstalled
    /// moat ran past the time limit.
    case timedOut(command: String)
    /// moat exited non-zero; `message` is the first line it printed.
    case failed(command: String, message: String)
    /// moat printed something OpenMoat Bar could not decode, often an older moat
    /// without `--format json` for that command.
    case unreadable(command: String)

    /// One line for the menu.
    public var message: String {
        switch self {
        case .notInstalled:
            return "OpenMoat isn't installed"
        case let .timedOut(command):
            return "openmoat \(command) took too long"
        case let .failed(command, message):
            return "openmoat \(command): \(message)"
        case let .unreadable(command):
            return "openmoat \(command) gave output OpenMoat Bar can't read. Update OpenMoat."
        }
    }
}
