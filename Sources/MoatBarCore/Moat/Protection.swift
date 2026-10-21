import Foundation

// `openmoat status --format json`. Shape: openmoat `crates/openmoat-cli/src/protection.rs`.

/// How much of the policy is enforced for one agent.
public enum Level: String, Codable, Equatable {
    case hookAndOsSandbox = "hook-and-os-sandbox"
    case hookOnly = "hook-only"
    case notProtected = "not-protected"
    case notSetUp = "not-set-up"
    case notFound = "not-found"
    /// A level a newer moat added. Never shown as protected.
    case unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Level(rawValue: raw) ?? .unknown
    }

    /// Whether the hook applies the policy to the agent's calls.
    public var isHooked: Bool {
        self == .hookAndOsSandbox || self == .hookOnly
    }

    /// Plain words for the menu.
    public var label: String {
        switch self {
        case .hookAndOsSandbox: return "Hook + sandbox"
        case .hookOnly: return "Hook only"
        case .notProtected: return "Not protected"
        case .notSetUp: return "Not set up"
        case .notFound: return "Not installed"
        case .unknown: return "Unknown"
        }
    }
}

/// One agent's protection: `agents[]` in `openmoat status --format json`.
public struct Protection: Codable, Equatable {
    /// Host id: `claude-code`, `codex`, `cursor`, `openclaw`, `copilot-cli`, `pi`, `gemini-cli`.
    public var host: String
    /// Display name: `Claude Code`.
    public var name: String
    public var level: Level
    /// Why the level is `hook-only` or `not-protected`.
    public var reason: String?
    /// What the hook and sandbox never cover for this agent.
    public var gaps: String

    public init(host: String, name: String, level: Level, reason: String? = nil, gaps: String = "") {
        self.host = host
        self.name = name
        self.level = level
        self.reason = reason
        self.gaps = gaps
    }
}

/// The whole `openmoat status --format json` document. Shape: openmoat
/// `crates/openmoat-cli/src/commands/status.rs`.
public struct StatusReport: Codable, Equatable {
    public var agents: [Protection]
    /// `3 changes from the OpenMoat 0.5.7 default` when `openmoat policy upgrade`
    /// has changes to offer.
    public var policyUpdate: String?
    /// Files OpenMoat pinned that changed since: `… was modified`, `… is missing`.
    public var lockDrift: [String]
    /// Whether moat sent `policy_update` and `lock_drift` at all. moat before
    /// 0.5.7 does not, so MoatBar can't say whether there is anything to show.
    public var hasUpdateNotices: Bool
    /// MCP server definitions and held tools that wait for `openmoat mcp accept`,
    /// one line each: ``MCP server `gh` in /path changed``. Empty when nothing
    /// waits, and from a moat that doesn't send it (before 0.5.7).
    public var mcpChanges: [String]
    /// Project settings files that could switch OpenMoat off or run a program,
    /// one line each: ``/path/.claude/settings.json: `hooks` adds hooks that run
    /// commands. A Claude Code session started here loads it; …``. Empty when
    /// there are none, and from a moat that doesn't send it (before 0.8.0).
    public var projectSettings: [String]

    public init(
        agents: [Protection],
        policyUpdate: String? = nil,
        lockDrift: [String] = [],
        hasUpdateNotices: Bool = true,
        mcpChanges: [String] = [],
        projectSettings: [String] = []
    ) {
        self.agents = agents
        self.policyUpdate = policyUpdate
        self.lockDrift = lockDrift
        self.hasUpdateNotices = hasUpdateNotices
        self.mcpChanges = mcpChanges
        self.projectSettings = projectSettings
    }

    private enum CodingKeys: String, CodingKey {
        case agents
        case policyUpdate = "policy_update"
        case lockDrift = "lock_drift"
        case mcpChanges = "mcp_changes"
        case projectSettings = "project_settings"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.agents = try c.decode([Protection].self, forKey: .agents)
        self.policyUpdate = try? c.decodeIfPresent(String.self, forKey: .policyUpdate)
        self.lockDrift = (try? c.decodeIfPresent([String].self, forKey: .lockDrift)) ?? []
        self.hasUpdateNotices = c.contains(.policyUpdate) || c.contains(.lockDrift)
        self.mcpChanges = (try? c.decodeIfPresent([String].self, forKey: .mcpChanges)) ?? []
        self.projectSettings = (try? c.decodeIfPresent([String].self, forKey: .projectSettings)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(self.agents, forKey: .agents)
        if self.hasUpdateNotices {
            try c.encode(self.policyUpdate, forKey: .policyUpdate)
            try c.encode(self.lockDrift, forKey: .lockDrift)
        }
        if !self.mcpChanges.isEmpty {
            try c.encode(self.mcpChanges, forKey: .mcpChanges)
        }
        if !self.projectSettings.isEmpty {
            try c.encode(self.projectSettings, forKey: .projectSettings)
        }
    }
}
