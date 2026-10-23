import Foundation

/// Commands OpenMoat Bar offers to copy. OpenMoat Bar never runs these; the person pastes
/// them into Terminal.
public enum CopyCommands {
    /// Set up or repair protection: `openmoat` alone shows the change and asks first.
    public static let setUp = "openmoat"

    /// Install OpenMoat with Homebrew.
    public static let install = "brew install crocodile-labs/tap/openmoat"

    /// Run every security check.
    public static let doctor = "openmoat doctor"

    /// Show the newer default policy's changes and ask before applying them.
    public static let policyUpgrade = "openmoat policy upgrade"

    /// Show what changed in one MCP server (or, without a name, in every one)
    /// and ask before accepting it. Only a person in a terminal can run it.
    public static func mcpAccept(_ server: String?) -> String {
        guard let server, !server.isEmpty else {
            return "openmoat mcp accept"
        }
        return "openmoat mcp accept \(self.shellQuoteIfNeeded(server))"
    }

    /// Take back a permanent rule `openmoat allow` wrote, as `openmoat allowed` prints it.
    public static func removeRule(_ id: String) -> String {
        "openmoat allow --remove \(self.shellQuoteIfNeeded(id))"
    }

    /// Stop trusting a repository's policy, as `openmoat allowed` prints it.
    public static func revokeTrust(_ root: String) -> String {
        "openmoat trust --revoke \(self.shellQuoteIfNeeded(root))"
    }

    /// Quoted only when the shell would split or expand it.
    public static func shellQuoteIfNeeded(_ text: String) -> String {
        let punctuation = Set("-_./:@+=,".unicodeScalars)
        let safe = !text.isEmpty && text.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || punctuation.contains(scalar))
        }
        return safe ? text : self.shellQuote(text)
    }

    /// `openmoat policy check` for this action, so the person can see the verdict
    /// and rule again without running anything. `nil` for kinds it can't check.
    public static func policyCheck(_ action: Action) -> String? {
        let (subject, kind): (String, String?)
        switch action {
        case let .shell(command): (subject, kind) = (command, nil)
        case let .fsRead(path): (subject, kind) = (path, "fs-read")
        case let .fsWrite(path): (subject, kind) = (path, "fs-write")
        case let .net(url): (subject, kind) = (url, "net")
        case let .fetch(url): (subject, kind) = (url, "fetch")
        case let .mcpTool(name): (subject, kind) = (name, "mcp")
        default: return nil
        }
        var line = "openmoat policy check \(self.shellQuote(subject))"
        if let kind {
            line += " --kind \(kind)"
        }
        return line
    }

    /// Single-quote for POSIX shells: `it's` → `'it'\''s'`.
    public static func shellQuote(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// Pages on openmoat.dev the menu links to.
public enum DocsLink {
    public static let home = URL(string: "https://openmoat.dev")!
    public static let blocked = URL(string: "https://openmoat.dev/docs/blocked/")!
    public static let checkACommand = URL(string: "https://openmoat.dev/docs/check-a-command/")!
    public static let quickstart = URL(string: "https://openmoat.dev/docs/quickstart/")!
    public static let troubleshooting = URL(string: "https://openmoat.dev/docs/troubleshooting/")!
    public static let limits = URL(string: "https://openmoat.dev/docs/limits/")!

    /// A new OpenMoat issue for a wrong block. Only the rule id goes in the
    /// title; the person adds the command themselves if they want to share it.
    public static func reportWrongBlock(rule: String?) -> URL {
        var components = URLComponents(string: "https://github.com/crocodile-labs/openmoat/issues/new")!
        let title = "False positive: \(rule ?? "a blocked call")"
        components.queryItems = [URLQueryItem(name: "title", value: title)]
        return components.url!
    }
}
