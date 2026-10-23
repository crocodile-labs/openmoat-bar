import Foundation
import XCTest
@testable import MoatBarCore

final class SecurityChecksTests: XCTestCase {
    private func snapshot(_ status: String, proxy: ProxyState?) throws -> Snapshot {
        try Snapshot(status: Fixture.decode(StatusReport.self, status), events: [], proxy: proxy, moatVersion: "0.5.3")
    }

    func test_worstFirst_withFixes() throws {
        let checks = try SecurityChecks.from(self.snapshot("status", proxy: .stopped))

        XCTAssertEqual(checks.map(\.id), ["proxy", "agent-codex", "moat", "agent-claude-code"])
        XCTAssertEqual(checks[0].kind, .warning)
        XCTAssertEqual(checks[0].fix, "openmoat proxy install")
        XCTAssertEqual(checks[1].kind, .info)
        XCTAssertEqual(checks[1].detail, "the sandbox profile is older than the policy")
        XCTAssertEqual(checks[1].fix, "openmoat")
    }

    func test_lostProtection_isAProblem_andNotFoundIsLeftOut() throws {
        let checks = try SecurityChecks.from(self.snapshot("status-unprotected", proxy: .running))

        XCTAssertEqual(checks.first?.id, "agent-claude-code")
        XCTAssertEqual(checks.first?.kind, .problem)
        XCTAssertFalse(checks.contains { $0.id == "agent-cursor" }, "an unknown level is not listed as a check")
    }

    func test_hookTurnedOffBySettings_saysWhichFileToEdit_andCopiesDoctor() throws {
        let snapshot = try self.snapshot("status-hook-off", proxy: nil)
        let checks = SecurityChecks.from(snapshot)
        let claude = try XCTUnwrap(checks.first { $0.id == "agent-claude-code" })
        let codex = try XCTUnwrap(checks.first { $0.id == "agent-codex" })

        XCTAssertEqual(claude.kind, .problem)
        XCTAssertEqual(claude.fix, "openmoat doctor")
        XCTAssertEqual(
            claude.detail?.hasSuffix(
                "Edit /Users/you/.claude/settings.json to remove what turns the hook off, "
                    + "then run openmoat doctor to check."
            ),
            true
        )
        XCTAssertEqual(codex.fix, "openmoat", "a missing hook is fixed by running openmoat")
        XCTAssertEqual(SecurityChecks.fix(for: snapshot.status.agents[0]), "openmoat doctor")
        XCTAssertEqual(
            SecurityChecks.hookTurnedOffBy(snapshot.status.agents[0].reason),
            "/Users/you/.claude/settings.json"
        )
        XCTAssertNil(SecurityChecks.hookTurnedOffBy("hook missing"))
        XCTAssertNil(SecurityChecks.hookTurnedOffBy(nil))
    }

    func test_attention_isWarningsAndProblems() throws {
        let fine = try SecurityChecks.from(self.snapshot("status", proxy: .running))
        XCTAssertEqual(SecurityChecks.needingAttention(fine), [], "hook only is shown but does not turn the icon amber")

        let stopped = try SecurityChecks.from(self.snapshot("status", proxy: .stopped))
        XCTAssertEqual(SecurityChecks.needingAttention(stopped).map(\.id), ["proxy"])

        let windows = try SecurityChecks.from(self.snapshot("status", proxy: nil))
        XCTAssertFalse(windows.contains { $0.id == "proxy" }, "no proxy line where moat has no proxy service")
    }
}
