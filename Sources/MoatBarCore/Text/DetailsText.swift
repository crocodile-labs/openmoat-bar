import Foundation

/// Words for the policy update and changed-file notices in the main view.
public enum UpdateNotices {
    public static let updateTitle = "Policy update available"
    public static let updateNote = "moat policy upgrade shows each change and asks before it applies any."
    public static let driftTitle = "OpenMoat's files changed"
    public static let driftNote = "Files OpenMoat checks changed since it pinned them. moat doctor shows what changed."
}

/// Words for the What you allowed and Secrets screens.
public enum DetailsText {
    /// The hint `moat secret list` prints for a secret whose source no deny rule covers.
    public static let exposedHint = "No deny rule covers its source: the agent can read the value there."
    /// What a covered source means.
    public static let coveredHint = "The agent can't read the value where OpenMoat reads it."
    /// What a plain-HTTP secret means.
    public static let plainHttpHint = "Also added to plain-HTTP requests, where it travels unencrypted."
    /// The command whose warning shows how to cover a source.
    public static let lint = "moat policy lint"

    /// `Ends in 3 h 20 min`, `Ends in 5 min`, `Ended`.
    public static func endsIn(_ expiresAtMs: Int64, nowMs: Int64) -> String {
        let left = expiresAtMs - nowMs
        guard left > 0 else {
            return "Ended"
        }
        let minutes = max(1, Int((left + 59999) / 60000))
        if minutes < 60 {
            return "Ends in \(minutes) min"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "Ends in \(hours) h" : "Ends in \(hours) h \(rest) min"
    }

    /// `Network: docs.rs, *.docs.rs`.
    public static func patternsLine(_ patterns: RulePatterns) -> String {
        "\(patterns.label): \(patterns.values.joined(separator: ", "))"
    }

    /// `api.github.com, Authorization header, from the variable GITHUB_TOKEN`.
    public static func secretLine(_ secret: BrokeredSecret) -> String {
        "\(secret.host), \(secret.header) header, from \(secret.source.label)"
    }

    /// The first 12 characters of a SHA-256, enough to tell two apart.
    public static func shortHash(_ sha256: String) -> String {
        String(sha256.prefix(12))
    }
}
