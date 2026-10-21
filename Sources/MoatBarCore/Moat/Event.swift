import Foundation

/// One audit event. `openmoat show --format json` prints an array of these.
/// Shape: openmoat `crates/openmoat-audit/src/store.rs` (`Event`).
public struct Event: Codable, Equatable, Identifiable {
    /// Row id in hex (`"1f"`); older moat builds wrote an integer.
    public var id: String
    /// Milliseconds since the epoch.
    public var tsMs: Int64
    /// Host id: an agent (`claude-code`, `codex`, `cursor`, `openclaw`, `copilot-cli`, `pi`,
    /// `gemini-cli`), or a part of OpenMoat that writes events (`proxy`, `mcp-proxy`, `moat-run`).
    public var host: String
    public var sessionId: String
    public var cwd: String?
    /// Tool name as the host spells it (`Bash`, `Read`).
    public var tool: String
    /// `nil` for a tool moat does not govern.
    public var action: Action?
    public var verdict: Verdict
    /// Rule ids that produced the verdict.
    public var rules: [String]
    /// One reason per rule: the words the agent was given.
    public var reasons: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case tsMs = "ts_ms"
        case host
        case sessionId = "session_id"
        case cwd
        case tool
        case action
        case verdict
        case rules
        case reasons
    }

    public init(
        id: String,
        tsMs: Int64,
        host: String,
        sessionId: String,
        cwd: String? = nil,
        tool: String,
        action: Action?,
        verdict: Verdict,
        rules: [String] = [],
        reasons: [String] = []
    ) {
        self.id = id
        self.tsMs = tsMs
        self.host = host
        self.sessionId = sessionId
        self.cwd = cwd
        self.tool = tool
        self.action = action
        self.verdict = verdict
        self.rules = rules
        self.reasons = reasons
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let hex = try? c.decode(String.self, forKey: .id) {
            self.id = hex
        } else {
            self.id = try String(c.decode(Int64.self, forKey: .id), radix: 16)
        }
        self.tsMs = try c.decode(Int64.self, forKey: .tsMs)
        self.host = try c.decode(String.self, forKey: .host)
        self.sessionId = try c.decode(String.self, forKey: .sessionId)
        self.cwd = try c.decodeIfPresent(String.self, forKey: .cwd)
        self.tool = try c.decode(String.self, forKey: .tool)
        // A stored action moat could not decode, or a shape a newer moat
        // added, leaves the tool name to show instead.
        self.action = try? c.decodeIfPresent(Action.self, forKey: .action)
        self.verdict = try c.decode(Verdict.self, forKey: .verdict)
        self.rules = try c.decodeIfPresent([String].self, forKey: .rules) ?? []
        self.reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
    }

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(self.tsMs) / 1000)
    }

    /// What the call did, in one line.
    public var display: String {
        self.action?.display ?? self.tool
    }

    /// The rule the menu names.
    public var rule: String? {
        self.rules.first
    }

    /// The words the agent was given.
    public var reason: String? {
        self.reasons.first
    }
}
