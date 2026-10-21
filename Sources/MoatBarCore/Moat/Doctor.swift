import Foundation

// `openmoat doctor --format json` (OpenMoat 0.5.5 and later). Shape: openmoat
// `crates/openmoat-cli/src/commands/doctor/json.rs`. moat exits non-zero when
// a check found a problem, after printing the document.

/// Every check `openmoat doctor` ran.
public struct DoctorReport: Decodable, Equatable {
    public var healthy: Bool
    public var problems: Int
    public var checks: [DoctorCheck]

    public init(healthy: Bool, problems: Int, checks: [DoctorCheck]) {
        self.healthy = healthy
        self.problems = problems
        self.checks = checks
    }

    /// The checks grouped by status, worst first. Inside a group, checks about
    /// the same thing (`DoctorTopic`) sit together, each topic in moat's order.
    /// Empty groups are left out.
    public var groups: [DoctorGroup] {
        DoctorStatus.allCases.reversed().compactMap { status in
            let checks = self.checks.enumerated()
                .filter { $0.element.status == status }
                .sorted { ($0.element.topic, $0.offset) < ($1.element.topic, $1.offset) }
                .map(\.element)
            return checks.isEmpty ? nil : DoctorGroup(status: status, checks: checks)
        }
    }
}

/// The checks with one status.
public struct DoctorGroup: Equatable, Identifiable {
    public var status: DoctorStatus
    public var checks: [DoctorCheck]

    public var id: DoctorStatus {
        self.status
    }
}

/// How a check reads. Ordered from fine to worst.
public enum DoctorStatus: Int, CaseIterable, Comparable, Decodable {
    /// `✔` in the text output.
    case ok = 0
    /// `·`: information.
    case note = 1
    /// `!`: needs a look.
    case warning = 2
    /// `✗`: a problem.
    case problem = 3

    public init(from decoder: Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "ok": self = .ok
        case "note": self = .note
        case "problem": self = .problem
        // "warning", and a status a newer moat added: never shown as fine.
        default: self = .warning
        }
    }

    public static func < (lhs: DoctorStatus, rhs: DoctorStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The heading for a group of checks.
    public var title: String {
        switch self {
        case .problem: return "Problems"
        case .warning: return "Needs a look"
        case .note: return "Notes"
        case .ok: return "Fine"
        }
    }
}

/// One line of `openmoat doctor`.
public struct DoctorCheck: Decodable, Equatable, Identifiable {
    public var status: DoctorStatus
    /// What the check is about: `policy`, `lock`, `hook`, ... Absent for notes.
    public var area: String?
    /// The left column of the text output (`policy`, `Claude Code`); may be empty.
    public var name: String
    public var detail: String
    /// Area, name and detail together. Views list rows by position, since moat
    /// can print the same line twice.
    public var id: String {
        "\(self.area ?? "")/\(self.name)/\(self.detail)"
    }

    public init(status: DoctorStatus, area: String? = nil, name: String, detail: String) {
        self.status = status
        self.area = area
        self.name = name
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey {
        case status, area, name, detail
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try c.decode(DoctorStatus.self, forKey: .status)
        self.area = try? c.decodeIfPresent(String.self, forKey: .area)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
    }

    /// The line's title: its name in plain words (`CheckText.label`), or the
    /// detail when the line has no name.
    public var title: String {
        self.name.isEmpty ? self.detail : CheckText.label(self.name)
    }

    /// What the check is about.
    public var topic: DoctorTopic {
        DoctorTopic(self)
    }

    /// The text under the title, empty when the title already is the detail.
    public var subtitle: String {
        self.name.isEmpty ? "" : self.detail
    }
}

/// What a `openmoat doctor` line is about, in the order the Checks screen keeps
/// them together. From the line's `area`, or for notes and warnings (which
/// have none) from its name.
public enum DoctorTopic: Int, CaseIterable, Comparable {
    case moat = 0
    case policy
    case lock
    case hooks
    case mcp
    case sandbox
    case proxy
    case agents
    case audit
    case other

    public init(_ check: DoctorCheck) {
        if let area = check.area {
            self = Self.byArea[area] ?? .other
            return
        }
        let name = check.name.lowercased()
        if let topic = Self.byName[name] {
            self = topic
        } else if check.detail.contains("onFailure") || check.detail.hasPrefix("hook runs the old") {
            // `Claude Code      runs a tool call when its hook fails…`, and after the
            // rename `Claude Code      hook runs the old `moat` name…`.
            self = .hooks
        } else if !name.isEmpty, Self.agentLines.contains(where: { check.detail.hasPrefix($0) }) {
            self = .agents
        } else {
            self = .other
        }
    }

    public static func < (lhs: DoctorTopic, rhs: DoctorTopic) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The caption beside a check.
    public var label: String {
        switch self {
        case .moat: return "OpenMoat"
        case .policy: return "Policy"
        case .lock: return "Pinned files"
        case .hooks: return "Hooks"
        case .mcp: return "MCP servers"
        case .sandbox: return "Sandboxes"
        case .proxy: return "Network proxy"
        case .agents: return "Agents"
        case .audit: return "Audit log"
        case .other: return "Other"
        }
    }

    /// `area` in openmoat `crates/openmoat-cli/src/commands/doctor.rs`.
    private static let byArea: [String: DoctorTopic] = [
        "state": .moat, "binary": .moat, "environment": .moat,
        "policy": .policy, "lock": .lock, "hook": .hooks, "mcp": .mcp,
        "sandbox": .sandbox, "service": .proxy, "audit": .audit,
    ]

    /// How the notes about one agent start (`Claude Code      protection: …`).
    private static let agentLines = ["protection:", "known gaps:", "host not found", "not set up"]

    /// The left column of rows without an area. `command`, `binary` and
    /// `openmoat run` are the rows about the `moat` name and `openmoat run`
    /// (openmoat `doctor/warnings.rs`).
    private static let byName: [String: DoctorTopic] = [
        "command": .moat, "binary": .moat, "state directory": .moat, "environment": .moat,
        "openmoat run": .moat, "moat run": .moat,
        "audit log": .audit, "audit anchor": .audit,
        "repo policy": .policy, "policy update": .policy,
        "mcp servers": .mcp, "mcp tools": .mcp,
        "guard": .hooks, "hook file": .hooks,
    ]
}
