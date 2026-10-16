import Foundation
import MoatBarCore

/// Made-up data for README screenshots: three agents, a morning of calls.
enum Sample {
    static func snapshot(now: Date) -> Snapshot {
        let status = StatusReport(agents: [
            Protection(host: "claude-code", name: "Claude Code", level: .hookAndOsSandbox),
            Protection(host: "codex", name: "Codex", level: .hookAndOsSandbox),
            Protection(host: "cursor", name: "Cursor", level: .notSetUp),
        ])
        return Snapshot(
            status: status,
            events: self.events(now: now),
            proxy: .running,
            moatVersion: "0.5.3",
            takenAt: now
        )
    }

    private struct Call {
        let minutesAgo: Double
        let host: String
        let session: String
        let cwd: String
        let tool: String
        let action: Action
        let verdict: Verdict
        let rule: String
        let reason: String
    }

    private static let blocked: [Call] = [
        Call(
            minutesAgo: 6, host: "codex", session: "app", cwd: "/Users/you/code/app", tool: "shell",
            action: .shell(command: "cat .env"), verdict: .deny, rule: "secrets-paths",
            reason: "secret material: read /Users/you/code/app/.env"
        ),
        Call(
            minutesAgo: 31, host: "claude-code", session: "moat", cwd: "/Users/you/code/openmoat", tool: "Read",
            action: .fsRead(path: "/Users/you/.ssh/id_ed25519"), verdict: .deny, rule: "secrets-paths",
            reason: "secret material: read /Users/you/.ssh/id_ed25519"
        ),
        Call(
            minutesAgo: 64, host: "claude-code", session: "site", cwd: "/Users/you/code/site", tool: "Bash",
            action: .shell(command: "git reset --hard"), verdict: .deny, rule: "destructive",
            reason: "destroys uncommitted work"
        ),
        Call(
            minutesAgo: 47, host: "claude-code", session: "moat", cwd: "/Users/you/code/openmoat", tool: "Bash",
            action: .shell(command: "git config core.hooksPath .h"), verdict: .ask, rule: "git-internals",
            reason: "changes which hooks git runs"
        ),
    ]

    private static func events(now: Date) -> [Event] {
        var calls = self.blocked
        // Normal work through the morning: builds, tests, reads, a few left to the agent.
        let routine: [(String, String, String, Action, Verdict, String)] = [
            ("claude-code", "moat", "Bash", .shell(command: "cargo test -p openmoat-core"), .allow, "dev-shell"),
            ("claude-code", "moat", "Read", .fsRead(path: "/Users/you/code/openmoat/README.md"), .allow, "project-fs"),
            ("codex", "app", "shell", .shell(command: "npm test"), .allow, "dev-shell"),
            ("codex", "app", "shell", .shell(command: "npm install left-pad"), .deferred, "default"),
            ("claude-code", "site", "Bash", .shell(command: "git status --short"), .allow, "dev-shell"),
            ("claude-code", "site", "Edit", .fsWrite(path: "/Users/you/code/site/index.md"), .allow, "project-fs"),
        ]
        for index in 0..<180 {
            let pick = routine[index % routine.count]
            let minutes = Double(index) * 1.4 + 2
            calls.append(Call(
                minutesAgo: minutes, host: pick.0, session: pick.1, cwd: "/Users/you/code/\(pick.1)",
                tool: pick.2, action: pick.3, verdict: pick.4, rule: pick.5, reason: ""
            ))
        }
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        return calls
            .map { call in
                Event(
                    id: String(Int(call.minutesAgo * 100), radix: 16),
                    tsMs: ms - Int64(call.minutesAgo * 60000),
                    host: call.host,
                    sessionId: call.session,
                    cwd: call.cwd,
                    tool: call.tool,
                    action: call.action,
                    verdict: call.verdict,
                    rules: [call.rule],
                    reasons: call.reason.isEmpty ? [] : [call.reason]
                )
            }
            .sorted { $0.tsMs < $1.tsMs }
    }
}
