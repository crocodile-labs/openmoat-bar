import Foundation

/// Words for `moat doctor` lines on the Checks screen: a plain name, one line
/// on what a check means, and the command to copy when one helps. The lines
/// come from openmoat `crates/openmoat-cli/src/commands/doctor.rs` (and
/// `doctor/mcp.rs`, `repo.rs`); a line MoatBar doesn't know shows as moat
/// wrote it. The desktop app has the same words in `desktop/src/core/Details.cpp`.
public enum CheckText {
    /// moat's left column in plain words: `repo policy` → `Repository policy`.
    public static func label(_ name: String) -> String {
        self.labels[name.lowercased()] ?? name
    }

    /// One line on what the check means; `nil` when the detail says it all.
    public static func hint(_ check: DoctorCheck) -> String? {
        let name = check.name.lowercased()
        let detail = check.detail
        switch check.topic {
        case .audit where name == "audit anchor":
            return "A copy of the audit log's latest hash, kept outside it. "
                + "moat audit verify --against checks the log against it later."
        case .policy where name == "repo policy":
            return self.repoPolicyHint(detail)
        case .mcp where detail.contains("not pinned yet"):
            return "Once pinned, a server definition that changes later is held back until you accept it."
        case .mcp where check.status == .problem:
            return "Its tool calls are refused until you accept the change."
        case .hooks where detail.contains("onFailure"):
            return "With this Claude Code, a tool call still runs when the OpenMoat hook crashes or times out."
        case .lock where self.isPackFile(detail):
            return "A signed policy pack changed after it was installed. Calls stop until a person looks."
        default:
            return nil
        }
    }

    /// The command that shows the change and asks, for MCP lines; `nil` otherwise.
    public static func fix(_ check: DoctorCheck) -> String? {
        guard check.topic == .mcp, check.status != .ok else {
            return nil
        }
        return CopyCommands.mcpAccept(self.quotedName(in: check.detail))
    }

    /// How the repository policy applies, from the end of moat's line
    /// (`… sha256:…  trusted: signed by alice (2 deny, 1 ask, 0 allow)`).
    static func repoPolicyHint(_ detail: String) -> String? {
        if let range = detail.range(of: "trusted: signed by ") {
            let signer = detail[range.upperBound...].split(separator: " ").first.map(String.init) ?? ""
            return "Signed by \(signer), a key you trust, so its allow rules apply too."
        }
        if detail.contains("not signed by a trusted key") {
            return "Not signed by a key you trust, so only its deny and ask rules apply."
        }
        if detail.contains("changed since `moat trust`") {
            return "Changed since you trusted it, so only its deny and ask rules apply."
        }
        if detail.contains("not trusted") {
            return "Not trusted, so only its deny and ask rules apply."
        }
        if detail.contains("tightening only") {
            return "It only adds deny and ask rules."
        }
        if detail.contains("trusted (") {
            return "Trusted with moat trust, so its allow rules apply too."
        }
        return nil
    }

    /// Installed packs live in `~/.moat/policy.d/packs/`, listed in `~/.moat/packs.json`.
    static func isPackFile(_ detail: String) -> Bool {
        detail.contains("policy.d/packs/") || detail.contains("policy.d\\packs\\") || detail.contains("packs.json")
    }

    /// The first name in backticks: `` `gh` in /path is new `` gives `gh`.
    static func quotedName(in text: String) -> String? {
        guard let start = text.firstIndex(of: "`") else {
            return nil
        }
        let rest = text[text.index(after: start)...]
        guard let end = rest.firstIndex(of: "`") else {
            return nil
        }
        let name = String(rest[..<end])
        // `moat mcp accept` in the "not pinned yet" line is a command, not a server.
        return name.isEmpty || name.contains(" ") ? nil : name
    }

    private static let labels: [String: String] = [
        "audit anchor": "Audit anchor",
        "audit log": "Audit log",
        "repo policy": "Repository policy",
        "policy update": "Policy update",
        "mcp servers": "MCP servers",
        "mcp tools": "MCP tools",
    ]
}
