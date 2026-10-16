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

    /// "✓ title" with the detail and, when there is a fix, "Click to copy …".
    static func checkRow(_ check: SecurityCheck, copyHint: Bool) -> NSAttributedString {
        let (symbol, color): (String, NSColor)
        switch check.kind {
        case .ok: (symbol, color) = ("✓", .systemGreen)
        case .info: (symbol, color) = ("i", .systemBlue)
        case .warning: (symbol, color) = ("!", .systemOrange)
        case .problem: (symbol, color) = ("!", .systemRed)
        }
        let text = NSMutableAttributedString(
            string: "\(symbol)  ",
            attributes: [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 13, weight: .bold)]
        )
        text.append(NSAttributedString(string: check.title, attributes: [.font: NSFont.systemFont(ofSize: 13)]))
        var lines: [String] = []
        if let detail = check.detail {
            lines.append(detail)
        }
        if copyHint, let fix = check.fix {
            lines.append("Click to copy: \(fix)")
        }
        if !lines.isEmpty {
            let body = "\n   " + lines.joined(separator: "\n   ")
            text.append(NSAttributedString(string: body, attributes: self.secondary))
        }
        return text
    }

    // MARK: - Helpers

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
