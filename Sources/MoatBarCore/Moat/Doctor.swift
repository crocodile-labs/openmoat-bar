import Foundation

// `moat doctor --format json` (OpenMoat 0.5.5 and later). Shape: openmoat
// `crates/openmoat-cli/src/commands/doctor/json.rs`. moat exits non-zero when
// a check found a problem, after printing the document.

/// Every check `moat doctor` ran.
public struct DoctorReport: Decodable, Equatable {
    public var healthy: Bool
    public var problems: Int
    public var checks: [DoctorCheck]

    public init(healthy: Bool, problems: Int, checks: [DoctorCheck]) {
        self.healthy = healthy
        self.problems = problems
        self.checks = checks
    }

    /// The checks grouped by status, worst first, each group in moat's order.
    /// Empty groups are left out.
    public var groups: [DoctorGroup] {
        DoctorStatus.allCases.reversed().compactMap { status in
            let checks = self.checks.filter { $0.status == status }
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

/// One line of `moat doctor`.
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

    /// The line's title: its name, or the detail when the line has no name.
    public var title: String {
        self.name.isEmpty ? self.detail : self.name
    }

    /// The text under the title, empty when the title already is the detail.
    public var subtitle: String {
        self.name.isEmpty ? "" : self.detail
    }
}
