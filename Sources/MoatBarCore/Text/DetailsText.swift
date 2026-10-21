import Foundation

/// Words for the policy update and changed-file notices in the main view.
public enum UpdateNotices {
    public static let updateTitle = "Policy update available"
    public static let updateNote = "openmoat policy upgrade shows each change and asks before it applies any."
    public static let driftTitle = "OpenMoat's files changed"
    public static let driftNote =
        "Files OpenMoat checks changed since it pinned them. openmoat doctor shows what changed."
    /// `project_settings` in `openmoat status --format json` (OpenMoat 0.8.0 and later).
    public static let projectSettingsTitle = "Project settings need a look"
    public static let projectSettingsNote = "An agent loads these when a session starts in that folder, "
        + "before any hook runs, so OpenMoat can only point at them."
}

/// Words for the MCP server changes in the main view, from `mcp_changes` in
/// `openmoat status --format json` (OpenMoat 0.5.7 and later).
public enum McpNotices {
    public static let title = "MCP server changes wait for you"
    public static let note = "OpenMoat refuses a changed server's tool calls until you accept it. "
        + "openmoat mcp accept shows each change and asks."

    /// The server a line names: ``MCP server `gh` in /path changed`` gives `gh`.
    /// `nil` for a line about a file moat could not read.
    public static func server(in line: String) -> String? {
        let prefix = "MCP server `"
        guard line.hasPrefix(prefix) else {
            return nil
        }
        let rest = line.dropFirst(prefix.count)
        guard let end = rest.firstIndex(of: "`") else {
            return nil
        }
        let name = String(rest[..<end])
        return name.isEmpty ? nil : name
    }

    /// The servers the lines name, each once, in moat's order.
    public static func servers(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        return lines.compactMap { self.server(in: $0) }.filter { seen.insert($0).inserted }
    }

    /// What to copy: `openmoat mcp accept <server>` per server, or plain
    /// `openmoat mcp accept` when no line names one.
    public static func acceptCommands(_ lines: [String]) -> [String] {
        let servers = self.servers(lines)
        return servers.isEmpty ? [CopyCommands.mcpAccept(nil)] : servers.map { CopyCommands.mcpAccept($0) }
    }
}

/// Words for the What you allowed and Secrets screens.
public enum DetailsText {
    /// The hint `openmoat secret list` prints for a secret whose source no deny rule covers.
    public static let exposedHint = "No deny rule covers its source: the agent can read the value there."
    /// What a covered source means.
    public static let coveredHint = "The agent can't read the value where OpenMoat reads it."
    /// What a plain-HTTP secret means.
    public static let plainHttpHint = "Also added to plain-HTTP requests, where it travels unencrypted."
    /// The command whose warning shows how to cover a source.
    public static let lint = "openmoat policy lint"

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
