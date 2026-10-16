import AppKit
import MoatBarCore

/// Text and small images for plain menu rows.
enum Format {
    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static func clock(_ date: Date) -> String {
        self.clockFormatter.string(from: date)
    }

    /// "just now", "4 min ago", then the clock time.
    static func relative(_ date: Date, now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 {
            return "just now"
        }
        if seconds < 3600 {
            return "\(Int(seconds / 60)) min ago"
        }
        return self.clock(date)
    }

    static func count(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }

    // MARK: - Rows

    private static var secondary: [NSAttributedString.Key: Any] {
        [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 11)]
    }

    private static var mono: [NSAttributedString.Key: Any] {
        [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
    }

    /// "Blocked   3" with the subtitle on a second line.
    static func verdictRow(_ verdict: Verdict, count: Int) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: verdict.title,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        text.append(NSAttributedString(
            string: "  \(self.count(count))",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)]
        ))
        text.append(NSAttributedString(string: "\n\(verdict.subtitle)", attributes: self.secondary))
        return text
    }

    /// The command on top, then rule · agent · folder · time.
    static func eventRow(_ event: Event, agent: String) -> NSAttributedString {
        let line = self.truncate(event.display, to: 60)
        let text = NSMutableAttributedString(string: line, attributes: event.action?.shellCommand != nil ? self.mono : [:])
        var parts: [String] = []
        if let rule = event.rule {
            parts.append(rule)
        }
        parts.append(agent)
        if let cwd = event.cwd {
            parts.append(self.shortPath(cwd))
        }
        parts.append(self.clock(event.date))
        text.append(NSAttributedString(string: "\n" + parts.joined(separator: " · "), attributes: self.secondary))
        return text
    }

    static func agentRow(_ agent: Protection, counts: [Verdict: Int], lastCall: String?) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: agent.name,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        var levelAttributes = self.secondary
        if agent.level == .notProtected {
            levelAttributes[.foregroundColor] = NSColor.systemRed
        }
        text.append(NSAttributedString(string: "  \(agent.level.label)", attributes: levelAttributes))
        let calls = counts.values.reduce(0, +)
        var line = "Blocked \(counts[.deny] ?? 0) · Asked \(counts[.ask] ?? 0) · \(self.count(calls)) calls"
        if let lastCall {
            line += " · \(lastCall)"
        }
        if agent.level == .notSetUp {
            line = "Run moat in Terminal to protect it"
        }
        text.append(NSAttributedString(string: "\n" + line, attributes: self.secondary))
        return text
    }

    static func sessionRow(_ session: Session, now: Date) -> NSAttributedString {
        let folder = session.cwd.map(self.shortPath) ?? "No folder"
        let text = NSMutableAttributedString(
            string: folder,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        let running = now.timeIntervalSince(session.last) < 600
        let span = "\(self.clock(session.first)) – \(running ? "now" : self.clock(session.last))"
        let line = "\(span) · \(self.count(session.total)) calls · Blocked \(session.counts[.deny] ?? 0)"
        text.append(NSAttributedString(string: "\n" + line, attributes: self.secondary))
        return text
    }

    // MARK: - Helpers

    static func dot(_ color: NSColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 9, height: 9), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return image
    }

    /// `/Users/you/code/app` → `~/code/app`.
    static func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func truncate(_ text: String, to length: Int) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        guard oneLine.count > length else {
            return oneLine
        }
        return String(oneLine.prefix(length - 1)) + "…"
    }
}

extension Verdict {
    var nsColor: NSColor {
        switch self {
        case .deny: return .systemRed
        case .ask: return .systemOrange
        case .deferred: return .systemBlue
        case .allow: return .systemGreen
        }
    }
}

extension Level {
    var nsColor: NSColor {
        switch self {
        case .hookAndOsSandbox: return .systemGreen
        case .hookOnly: return .systemOrange
        case .notProtected: return .systemRed
        case .notSetUp, .notFound, .unknown: return .tertiaryLabelColor
        }
    }
}
