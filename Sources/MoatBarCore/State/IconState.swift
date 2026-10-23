import Foundation

/// What the menu bar icon shows. When several apply, the highest wins.
public enum IconState: Int, Comparable, CaseIterable {
    /// moat is missing or could not be read: grey.
    case unavailable = 0
    /// Every agent that is set up is protected and nothing is new: plain.
    case quiet = 1
    /// Blocks since the menu was last opened: a dot.
    case newBlocks = 2
    /// A security check needs a look: amber.
    case attention = 3
    /// An agent that was set up is not protected now: red.
    case unprotected = 4

    public static func < (lhs: IconState, rhs: IconState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Decide the icon.
    /// - Parameters:
    ///   - snapshot: the last good read, or `nil` when moat is missing or unreadable.
    ///   - seenUntilMs: the newest event time the person has already seen in the menu.
    ///   - needsAttention: a security check needs a look.
    public static func decide(
        snapshot: Snapshot?,
        seenUntilMs: Int64?,
        needsAttention: Bool = false
    ) -> IconState {
        guard let snapshot else {
            return .unavailable
        }
        if !snapshot.unprotected.isEmpty {
            return .unprotected
        }
        if needsAttention {
            return .attention
        }
        if let newest = snapshot.newestBlockMs, newest > (seenUntilMs ?? Int64.min) {
            return .newBlocks
        }
        return .quiet
    }

    /// Words for VoiceOver and the icon's tooltip.
    public var accessibilityLabel: String {
        switch self {
        case .unavailable: return "OpenMoat Bar: OpenMoat not found"
        case .quiet: return "OpenMoat Bar: all protected"
        case .newBlocks: return "OpenMoat Bar: new blocked calls"
        case .attention: return "OpenMoat Bar: a security check needs a look"
        case .unprotected: return "OpenMoat Bar: an agent is not protected"
        }
    }
}
