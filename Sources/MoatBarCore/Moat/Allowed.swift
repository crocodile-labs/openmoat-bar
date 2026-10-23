import Foundation

// `openmoat allowed --format json` (OpenMoat 0.5.5 and later). Shape: openmoat
// `crates/openmoat-cli/src/commands/allowed.rs`; a rule is a `RuleGroup` from
// `crates/openmoat-core/src/policy.rs`.

/// Everything a person allowed: permanent rules, session grants that have not
/// ended, and repositories whose own policy they trusted.
public struct AllowedReport: Decodable, Equatable {
    public var rules: [AllowedRule]
    public var sessionGrants: [SessionGrant]
    public var trustedRepos: [TrustedRepo]

    public init(rules: [AllowedRule] = [], sessionGrants: [SessionGrant] = [], trustedRepos: [TrustedRepo] = []) {
        self.rules = rules
        self.sessionGrants = sessionGrants
        self.trustedRepos = trustedRepos
    }

    private enum CodingKeys: String, CodingKey {
        case rules
        case sessionGrants = "session_grants"
        case trustedRepos = "trusted_repos"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.rules = try c.decodeIfPresent([AllowedRule].self, forKey: .rules) ?? []
        self.sessionGrants = try c.decodeIfPresent([SessionGrant].self, forKey: .sessionGrants) ?? []
        self.trustedRepos = try c.decodeIfPresent([TrustedRepo].self, forKey: .trustedRepos) ?? []
    }

    public var isEmpty: Bool {
        self.rules.isEmpty && self.sessionGrants.isEmpty && self.trustedRepos.isEmpty
    }
}

/// One permanent rule from `openmoat allow --always`, `--site` or `--dir`.
public struct AllowedRule: Decodable, Equatable, Identifiable {
    public var id: String
    public var reason: String?
    /// The patterns per kind, in the order `openmoat allowed` prints them.
    public var patterns: [RulePatterns]

    public init(id: String, reason: String? = nil, patterns: [RulePatterns]) {
        self.id = id
        self.reason = reason
        self.patterns = patterns
    }

    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? {
            nil
        }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        self.id = try c.decode(String.self, forKey: Key(stringValue: "id"))
        self.reason = try? c.decodeIfPresent(String.self, forKey: Key(stringValue: "reason"))
        // Kinds moat knows today, in its order; a kind a newer moat adds is
        // still listed after them, under its own name.
        let known = RulePatterns.kinds
        let extra = c.allKeys.map(\.stringValue).filter { !known.contains($0) && $0 != "id" && $0 != "reason" }
        self.patterns = (known + extra.sorted()).compactMap { kind in
            guard let values = try? c.decode([String].self, forKey: Key(stringValue: kind)), !values.isEmpty else {
                return nil
            }
            return RulePatterns(kind: kind, values: values)
        }
    }
}

/// The patterns a rule lists for one kind of call.
public struct RulePatterns: Equatable {
    /// moat's name for the kind: `shell`, `fs.read`, `net`, ...
    public var kind: String
    public var values: [String]

    public init(kind: String, values: [String]) {
        self.kind = kind
        self.values = values
    }

    /// moat's kinds, in the order it prints them (`Kind::ALL`).
    public static let kinds = ["shell", "fs.read", "fs.write", "net", "fetch", "env.read", "env.set", "mcp"]

    /// Plain words for the kind.
    public var label: String {
        switch self.kind {
        case "shell": return "Commands"
        case "fs.read": return "Read files"
        case "fs.write": return "Write files"
        case "net": return "Network"
        case "fetch": return "Fetch pages"
        case "env.read": return "Read variables"
        case "env.set": return "Set variables"
        case "mcp": return "MCP tools"
        default: return self.kind
        }
    }
}

/// One `openmoat allow --last` answer that still applies to its session.
public struct SessionGrant: Decodable, Equatable, Identifiable {
    /// Agent host id: `claude-code`, `codex`, `gemini-cli`, ...
    public var host: String
    public var sessionId: String
    /// What it allows, in moat's words: `run "npm install"`.
    public var what: String
    public var grantedAtMs: Int64
    public var expiresAtMs: Int64
    /// The project the grant applies in (OpenMoat 0.10.0 and later); `nil` for a
    /// file grant, which needs none, and from an older moat.
    public var project: String?
    /// `false` for a grant an earlier OpenMoat wrote without the project it
    /// needs: it applies nowhere until it is approved again. An older moat
    /// doesn't send it; its grants apply.
    public var applies: Bool

    public var id: String {
        "\(self.host)/\(self.sessionId)/\(self.grantedAtMs)/\(self.what)"
    }

    public init(
        host: String,
        sessionId: String,
        what: String,
        grantedAtMs: Int64,
        expiresAtMs: Int64,
        project: String? = nil,
        applies: Bool = true
    ) {
        self.host = host
        self.sessionId = sessionId
        self.what = what
        self.grantedAtMs = grantedAtMs
        self.expiresAtMs = expiresAtMs
        self.project = project
        self.applies = applies
    }

    private enum CodingKeys: String, CodingKey {
        case host
        case sessionId = "session_id"
        case what
        case grantedAtMs = "granted_at_ms"
        case expiresAtMs = "expires_at_ms"
        case project, applies
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.host = try c.decode(String.self, forKey: .host)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.what = try c.decode(String.self, forKey: .what)
        self.grantedAtMs = try c.decode(Int64.self, forKey: .grantedAtMs)
        self.expiresAtMs = try c.decode(Int64.self, forKey: .expiresAtMs)
        self.project = try? c.decodeIfPresent(String.self, forKey: .project)
        self.applies = (try? c.decodeIfPresent(Bool.self, forKey: .applies)) ?? true
    }
}

/// A repository whose `.moat/policy.yaml` was trusted with `openmoat trust`.
public struct TrustedRepo: Decodable, Equatable, Identifiable {
    public var root: String
    /// SHA-256 of the trusted policy file; a change to the file ends the trust.
    public var sha256: String

    public var id: String {
        self.root
    }

    public init(root: String, sha256: String) {
        self.root = root
        self.sha256 = sha256
    }
}
