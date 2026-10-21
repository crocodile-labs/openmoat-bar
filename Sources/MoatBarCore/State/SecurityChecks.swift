import Foundation

/// One line in Security checks: what is fine, what needs a look, and the one
/// command that fixes it.
public struct SecurityCheck: Equatable, Identifiable {
    public enum Kind: Int, Comparable {
        case ok = 0
        case info = 1
        case warning = 2
        case problem = 3

        public static func < (lhs: Kind, rhs: Kind) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var id: String
    public var kind: Kind
    public var title: String
    public var detail: String?
    /// A command to copy into Terminal, if one fixes it.
    public var fix: String?

    public init(id: String, kind: Kind, title: String, detail: String? = nil, fix: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.fix = fix
    }
}

/// Checks built from what moat already reports (status, proxy status,
/// version). `openmoat doctor` checks more; MoatBar shows those once moat can
/// print them as JSON.
public enum SecurityChecks {
    public static func from(_ snapshot: Snapshot) -> [SecurityCheck] {
        var checks: [SecurityCheck] = []
        if let version = snapshot.moatVersion {
            checks.append(SecurityCheck(id: "moat", kind: .ok, title: "openmoat \(version) is installed"))
        }
        for agent in snapshot.status.agents {
            if let check = self.agentCheck(agent) {
                checks.append(check)
            }
        }
        if let proxy = snapshot.proxy {
            checks.append(self.proxyCheck(proxy))
        }
        if !snapshot.status.lockDrift.isEmpty {
            checks.append(SecurityCheck(
                id: "lock",
                kind: .problem,
                title: UpdateNotices.driftTitle,
                detail: snapshot.status.lockDrift.joined(separator: "\n"),
                fix: CopyCommands.doctor
            ))
        }
        // OpenMoat 0.5.7 and later; an older moat sends nothing, so no check.
        if !snapshot.status.mcpChanges.isEmpty {
            let commands = McpNotices.acceptCommands(snapshot.status.mcpChanges)
            checks.append(SecurityCheck(
                id: "mcp",
                kind: .warning,
                title: McpNotices.title,
                detail: snapshot.status.mcpChanges.joined(separator: "\n"),
                fix: commands.count == 1 ? commands[0] : CopyCommands.mcpAccept(nil)
            ))
        }
        if let update = snapshot.status.policyUpdate {
            checks.append(SecurityCheck(
                id: "policy-update",
                kind: .info,
                title: UpdateNotices.updateTitle,
                detail: update,
                fix: CopyCommands.policyUpgrade
            ))
        }
        // Worst first, then in moat's order.
        return checks.enumerated()
            .sorted { $0.element.kind != $1.element.kind ? $0.element.kind > $1.element.kind : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Checks that need a look: warnings and problems.
    public static func needingAttention(_ checks: [SecurityCheck]) -> [SecurityCheck] {
        checks.filter { $0.kind >= .warning }
    }

    private static func agentCheck(_ agent: Protection) -> SecurityCheck? {
        let id = "agent-\(agent.host)"
        switch agent.level {
        case .hookAndOsSandbox:
            return SecurityCheck(id: id, kind: .ok, title: "\(agent.name): every call checked, inside a sandbox")
        case .hookOnly:
            // Info, not a warning: on native Windows there is no OS sandbox to
            // turn on, and the icon must not stay amber for that.
            return SecurityCheck(
                id: id,
                kind: .info,
                title: "\(agent.name): calls checked, no OS sandbox",
                detail: agent.reason,
                fix: CopyCommands.setUp
            )
        case .notProtected:
            return SecurityCheck(
                id: id,
                kind: .problem,
                title: "\(agent.name) is not protected",
                detail: agent.reason,
                fix: CopyCommands.setUp
            )
        case .notSetUp:
            return SecurityCheck(
                id: id,
                kind: .info,
                title: "\(agent.name) is installed but not set up",
                detail: "openmoat asks before it changes anything and shows the diff.",
                fix: CopyCommands.setUp
            )
        case .notFound, .unknown:
            return nil
        }
    }

    private static func proxyCheck(_ proxy: ProxyState) -> SecurityCheck {
        let id = "proxy"
        switch proxy {
        case .running:
            return SecurityCheck(id: id, kind: .ok, title: "Network proxy is running")
        case .notInstalled:
            return SecurityCheck(
                id: id,
                kind: .info,
                title: "Network proxy isn't kept running",
                detail: "Without it, kept-back tokens can't be added to requests.",
                fix: "openmoat proxy install"
            )
        case .stopped:
            return SecurityCheck(
                id: id, kind: .warning, title: "Network proxy is stopped", fix: "openmoat proxy install"
            )
        case .driftBlocked:
            return SecurityCheck(
                id: id,
                kind: .problem,
                title: "Network proxy stopped after a watched file changed",
                detail: "Look at the change first, then start the proxy again.",
                fix: CopyCommands.doctor
            )
        case .crashlooping:
            return SecurityCheck(
                id: id,
                kind: .warning,
                title: "Network proxy keeps crashing",
                detail: "Check the service log, then start it again.",
                fix: "openmoat proxy install"
            )
        case let .unknown(details):
            return SecurityCheck(id: id, kind: .info, title: "Network proxy: state unknown", detail: details)
        }
    }
}
