import Foundation
import XCTest
@testable import MoatBarCore

/// What you allowed, Secrets, Checks, the status notices, and what an older
/// moat gets instead of an error.
final class DetailsTests: XCTestCase {
    private let binary = URL(fileURLWithPath: "/opt/homebrew/bin/moat")

    // MARK: - Decoding

    func test_allowed_decodesRulesGrantsAndRepos() throws {
        let allowed = try Fixture.decode(AllowedReport.self, "allowed")

        XCTAssertEqual(allowed.rules.map(\.id), ["approved-1", "approved-site-docs-rs", "approved-dir-1"])
        XCTAssertEqual(allowed.rules[0].patterns, [RulePatterns(kind: "shell", values: ["npm install"])])
        XCTAssertEqual(allowed.rules[1].reason, "allowed with moat allow --site")
        XCTAssertEqual(allowed.rules[1].patterns.map(\.kind), ["net", "fetch"])
        XCTAssertEqual(allowed.rules[2].patterns.map(\.label), ["Read files", "Write files", "MCP tools"])
        XCTAssertEqual(DetailsText.patternsLine(allowed.rules[1].patterns[0]), "Network: docs.rs, *.docs.rs")

        XCTAssertEqual(allowed.sessionGrants.count, 2)
        XCTAssertEqual(allowed.sessionGrants[0].host, "claude-code")
        XCTAssertEqual(allowed.sessionGrants[0].what, "run \"cargo publish --dry-run\"")
        XCTAssertEqual(allowed.sessionGrants[0].expiresAtMs, 1_792_072_400_000)

        XCTAssertEqual(allowed.trustedRepos, [TrustedRepo(
            root: "/Users/you/code/team app",
            sha256: "9f2c4a7e0b1d3f5a6c8e9b0d1f2a3c4e5b6d7f8a9c0e1b2d3f4a5c6e7b8d9f0a"
        )])
    }

    func test_allowed_emptyDocument_isEmpty() throws {
        let allowed = try JSONDecoder().decode(
            AllowedReport.self,
            from: Data(#"{"rules": [], "session_grants": [], "trusted_repos": []}"#.utf8)
        )
        XCTAssertTrue(allowed.isEmpty)
    }

    func test_secrets_decodeSourcesAndExposure() throws {
        let list = try Fixture.decode(SecretList.self, "secret-list")

        XCTAssertEqual(list.secrets.map(\.id), ["gh", "openai", "internal", "future"])
        XCTAssertEqual(list.secrets[0].source, .env("GITHUB_TOKEN"))
        XCTAssertTrue(list.secrets[0].sourceExposed)
        XCTAssertEqual(list.secrets[1].source, .file("~/.config/openai/key"))
        XCTAssertEqual(list.secrets[2].source, .keychain(service: "build-api", account: "you"))
        XCTAssertTrue(list.secrets[2].plainHttp)
        XCTAssertFalse(list.secrets[1].plainHttp)
        XCTAssertEqual(list.secrets[3].source, .unknown, "a source a newer moat added still decodes")
        XCTAssertEqual(list.exposed.map(\.id), ["gh"])
        XCTAssertEqual(
            DetailsText.secretLine(list.secrets[0]),
            "api.github.com, Authorization header, from the variable GITHUB_TOKEN"
        )
    }

    func test_secret_withoutSourceExposed_countsAsExposed() throws {
        let json = #"{"secrets": [{"id": "a", "host": "h", "header": "X", "source": {"env": "A"}}]}"#
        let list = try JSONDecoder().decode(SecretList.self, from: Data(json.utf8))
        XCTAssertTrue(list.secrets[0].sourceExposed)
    }

    func test_doctor_groupsByStatus_worstFirst() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor")

        XCTAssertFalse(report.healthy)
        XCTAssertEqual(report.problems, 1)
        XCTAssertEqual(report.checks.count, 7)
        XCTAssertEqual(report.groups.map(\.status), [.problem, .warning, .note, .ok])
        XCTAssertEqual(report.groups.map(\.checks.count), [1, 2, 1, 3])
        XCTAssertEqual(report.groups[0].checks[0].area, "lock")
        XCTAssertEqual(report.groups.map(\.status.title), ["Problems", "Needs a look", "Notes", "Fine"])
    }

    func test_doctor_unknownStatus_isNeverFine() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor")
        XCTAssertEqual(report.checks[6].status, .warning)
    }

    func test_doctor_rowWithoutName_showsTheDetailAsTitle() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor")
        let row = report.checks[3]
        XCTAssertNil(row.area)
        XCTAssertEqual(row.title, row.detail)
        XCTAssertEqual(row.subtitle, "")
        XCTAssertEqual(report.checks[1].subtitle, "/Users/you/.moat/policy.yaml (31 deny, 12 allow, 9 ask)")
    }

    func test_status_decodesUpdateNotices() throws {
        let status = try Fixture.decode(StatusReport.self, "status-notices")

        XCTAssertEqual(status.policyUpdate, "3 changes from the OpenMoat 0.5.7 default")
        XCTAssertEqual(status.lockDrift.count, 2)
        XCTAssertTrue(status.hasUpdateNotices)
        XCTAssertNil(MoatRequirement.updateNoticesNote(for: status))
    }

    func test_status_fromOlderMoat_hasNoNoticesAndSaysWhy() throws {
        let status = try Fixture.decode(StatusReport.self, "status")

        XCTAssertNil(status.policyUpdate)
        XCTAssertEqual(status.lockDrift, [])
        XCTAssertFalse(status.hasUpdateNotices)
        XCTAssertEqual(
            MoatRequirement.updateNoticesNote(for: status),
            "Policy update and changed-file notices need OpenMoat 0.5.7 or later."
        )
    }

    func test_status_nullUpdate_isANewerMoatWithNothingToShow() throws {
        let json = #"{"agents": [], "policy_update": null, "lock_drift": []}"#
        let status = try JSONDecoder().decode(StatusReport.self, from: Data(json.utf8))
        XCTAssertNil(status.policyUpdate)
        XCTAssertTrue(status.hasUpdateNotices)
    }

    // MARK: - Security checks from the notices

    func test_securityChecks_lockDriftIsAProblem_updateIsInfo() throws {
        let status = try Fixture.decode(StatusReport.self, "status-notices")
        let checks = SecurityChecks.from(Snapshot(status: status, events: []))

        let lock = try XCTUnwrap(checks.first { $0.id == "lock" })
        XCTAssertEqual(lock.kind, .problem)
        XCTAssertEqual(lock.fix, "moat doctor")
        let update = try XCTUnwrap(checks.first { $0.id == "policy-update" })
        XCTAssertEqual(update.kind, .info)
        XCTAssertEqual(update.fix, "moat policy upgrade")
        XCTAssertEqual(SecurityChecks.needingAttention(checks).map(\.id), ["lock"])
    }

    // MARK: - Newer doctor lines (OpenMoat 0.5.7 and main)

    func test_doctor_groupsLikeChecksTogether_andNamesTheirTopic() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor-signed")

        XCTAssertEqual(report.groups.map(\.status), [.problem, .warning, .note, .ok])
        // Problems: the pinned pack file first, then both MCP lines.
        XCTAssertEqual(report.groups[0].checks.map(\.topic), [.lock, .mcp, .mcp])
        XCTAssertEqual(report.groups[1].checks.map(\.topic), [.hooks])
        XCTAssertEqual(report.groups[2].checks.map(\.topic), [.policy, .audit, .audit])
        XCTAssertEqual(report.groups[3].checks.map(\.topic), [.policy, .hooks, .audit])
        XCTAssertEqual(report.groups[2].checks.map(\.title), ["Repository policy", "Audit log", "Audit anchor"])
        XCTAssertEqual(DoctorTopic.mcp.label, "MCP servers")
    }

    func test_doctor_auditAnchor_isExplained() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor-signed")
        let anchor = try XCTUnwrap(report.checks.first { $0.name == "audit anchor" })

        XCTAssertEqual(anchor.status, .note)
        XCTAssertTrue(anchor.subtitle.hasPrefix("last made 2026-10-18 09:12:44 UTC (event 1198)"))
        XCTAssertEqual(CheckText.hint(anchor)?.hasPrefix("A copy of the audit log's latest hash"), true)
        XCTAssertNil(CheckText.fix(anchor))
    }

    func test_doctor_repoPolicy_saysWhoSignedIt() throws {
        let signed = try Fixture.decode(DoctorReport.self, "doctor-signed")
        let repo = try XCTUnwrap(signed.checks.first { $0.name == "repo policy" })
        XCTAssertEqual(
            CheckText.hint(repo),
            "Signed by alice@example.com, a key you trust, so its allow rules apply too."
        )

        let unsigned = try Fixture.decode(DoctorReport.self, "doctor-mcp-unpinned")
        let other = try XCTUnwrap(unsigned.checks.first { $0.name == "repo policy" })
        XCTAssertEqual(CheckText.hint(other), "Not signed by a key you trust, so only its deny and ask rules apply.")

        XCTAssertEqual(
            CheckText.repoPolicyHint("p  sha256:1  changed since `moat trust`: tightening only (1 deny)"),
            "Changed since you trusted it, so only its deny and ask rules apply."
        )
        XCTAssertEqual(
            CheckText.repoPolicyHint("p  sha256:1  trusted (1 deny, 0 ask, 1 allow)"),
            "Trusted with moat trust, so its allow rules apply too."
        )
        XCTAssertEqual(
            CheckText.repoPolicyHint("p  sha256:1  tightening only (1 deny, 0 ask, 0 allow)"),
            "It only adds deny and ask rules."
        )
        XCTAssertNil(CheckText.repoPolicyHint("something a newer moat says"))
    }

    func test_doctor_changedPolicyPack_isExplained() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor-signed")
        let lock = try XCTUnwrap(report.checks.first { $0.area == "lock" })

        XCTAssertEqual(CheckText.hint(lock)?.hasPrefix("A signed policy pack changed"), true)
        XCTAssertTrue(CheckText.isPackFile(#"C:\Users\you\.moat\policy.d\packs\team.yaml was modified"#))
        XCTAssertFalse(CheckText.isPackFile("/Users/you/.moat/policy.yaml was modified"))
    }

    func test_doctor_mcpLines_copyTheAcceptCommandForTheirServer() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor-signed")
        let mcp = report.checks.filter { $0.topic == .mcp }

        XCTAssertEqual(mcp.map(\.title), ["MCP servers", "MCP tools"])
        XCTAssertEqual(mcp.map { CheckText.fix($0) }, ["moat mcp accept gh", "moat mcp accept docs"])
        XCTAssertEqual(CheckText.hint(mcp[0]), "Its tool calls are refused until you accept the change.")

        let unpinned = try Fixture.decode(DoctorReport.self, "doctor-mcp-unpinned").checks[0]
        XCTAssertEqual(unpinned.topic, .mcp)
        XCTAssertEqual(CheckText.fix(unpinned), "moat mcp accept")
        XCTAssertEqual(CheckText.hint(unpinned)?.hasPrefix("Once pinned"), true)
    }

    func test_doctor_hookWithoutOnFailure_isAHookWarning() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor-signed")
        let row = try XCTUnwrap(report.checks.first { $0.detail.contains("onFailure") })

        XCTAssertEqual(row.status, .warning)
        XCTAssertEqual(row.topic, .hooks)
        XCTAssertEqual(row.title, "Claude Code")
        XCTAssertEqual(CheckText.hint(row)?.contains("still runs when the OpenMoat hook crashes"), true)
    }

    func test_doctor_olderLines_keepTheirWords() throws {
        let report = try Fixture.decode(DoctorReport.self, "doctor")
        XCTAssertEqual(report.checks.map(\.title)[0...2], ["state directory", "policy", "lock"])
        XCTAssertTrue(report.checks.allSatisfy { CheckText.fix($0) == nil })
        XCTAssertEqual(report.checks[6].topic, .other)
    }

    // MARK: - MCP server changes from moat status

    func test_status_decodesMcpChanges() throws {
        let status = try Fixture.decode(StatusReport.self, "status-mcp")

        XCTAssertEqual(status.mcpChanges.count, 4)
        XCTAssertEqual(McpNotices.servers(status.mcpChanges), ["gh", "docs"])
        XCTAssertEqual(McpNotices.acceptCommands(status.mcpChanges), ["moat mcp accept gh", "moat mcp accept docs"])
        XCTAssertNil(McpNotices.server(in: status.mcpChanges[3]))
    }

    func test_status_withoutMcpChanges_showsNothing() throws {
        for name in ["status", "status-notices"] {
            let status = try Fixture.decode(StatusReport.self, name)
            XCTAssertEqual(status.mcpChanges, [], name)
            let checks = SecurityChecks.from(Snapshot(status: status, events: []))
            XCTAssertFalse(checks.contains { $0.id == "mcp" }, name)
        }
    }

    func test_mcpNotices_unnamedLines_copyThePlainCommand() {
        let lines = ["/Users/you/.cursor/mcp.json cannot be read: denied"]
        XCTAssertEqual(McpNotices.acceptCommands(lines), ["moat mcp accept"])
        XCTAssertEqual(CopyCommands.mcpAccept("team docs"), "moat mcp accept 'team docs'")
        XCTAssertNil(McpNotices.server(in: "MCP server `` in /x changed"))
    }

    func test_securityChecks_mcpChangesNeedALook() throws {
        let status = try Fixture.decode(StatusReport.self, "status-mcp")
        let checks = SecurityChecks.from(Snapshot(status: status, events: []))

        let mcp = try XCTUnwrap(checks.first { $0.id == "mcp" })
        XCTAssertEqual(mcp.kind, .warning)
        XCTAssertEqual(mcp.title, McpNotices.title)
        XCTAssertEqual(mcp.fix, "moat mcp accept", "two servers: the command that shows every change")
        XCTAssertEqual(SecurityChecks.needingAttention(checks).map(\.id), ["mcp"])

        let one = StatusReport(agents: status.agents, mcpChanges: ["MCP server `gh` in /x changed"])
        let single = SecurityChecks.from(Snapshot(status: one, events: [])).first { $0.id == "mcp" }
        XCTAssertEqual(single?.fix, "moat mcp accept gh")
    }

    // MARK: - Older moat

    func test_version_comparesNumbers() {
        XCTAssertEqual(MoatVersion.isAtLeast("0.5.5", "0.5.5"), true)
        XCTAssertEqual(MoatVersion.isAtLeast("0.5.10", "0.5.7"), true)
        XCTAssertEqual(MoatVersion.isAtLeast("0.6.0", "0.5.7"), true)
        XCTAssertEqual(MoatVersion.isAtLeast("0.5.4", "0.5.5"), false)
        XCTAssertEqual(MoatVersion.isAtLeast("0.5.7-rc.1", "0.5.7"), true)
        XCTAssertNil(MoatVersion.isAtLeast(nil, "0.5.5"))
        XCTAssertNil(MoatVersion.isAtLeast("dev", "0.5.5"))
    }

    func test_screen_olderVersion_givesTheNoteWithoutRunning() {
        var ran = false
        let state = ScreenState<Int>.read(minimum: "0.5.5", version: "0.5.4") {
            ran = true
            return 1
        }
        XCTAssertFalse(ran)
        XCTAssertEqual(state, .needsNewerMoat(note: "This needs OpenMoat 0.5.5 or later. Update moat to see it here."))
    }

    func test_screen_unknownVersion_unknownCommand_givesTheNote() {
        let state = ScreenState<Int>.read(minimum: "0.5.5", version: nil) {
            throw MoatError.failed(command: "allowed", message: "error: unrecognized subcommand 'allowed'")
        }
        XCTAssertEqual(state, .needsNewerMoat(note: MoatRequirement.note("0.5.5")))

        let text = ScreenState<Int>.read(minimum: "0.5.5", version: nil) {
            throw MoatError.unreadable(command: "doctor")
        }
        XCTAssertEqual(text, .needsNewerMoat(note: MoatRequirement.note("0.5.5")))
    }

    func test_screen_newEnoughMoat_failing_isAnError() {
        let state = ScreenState<Int>.read(minimum: "0.5.5", version: "0.5.6") {
            throw MoatError.failed(command: "allowed", message: "error: unrecognized subcommand 'allowed'")
        }
        XCTAssertEqual(state, .failed(message: "moat allowed: error: unrecognized subcommand 'allowed'"))

        let timeout = ScreenState<Int>.read(minimum: "0.5.5", version: nil) {
            throw MoatError.timedOut(command: "doctor --format json")
        }
        XCTAssertEqual(timeout, .failed(message: "moat doctor --format json took too long"))
    }

    func test_details_readsAllThreeScreens() throws {
        let runner = StubRunner()
        runner.outputs = try [
            "--version": .success(Data("moat 0.5.6 (OpenMoat)\n".utf8)),
            "allowed": .success(Fixture.data("allowed")),
            "secret": .success(Fixture.data("secret-list")),
            "doctor": .success(Fixture.data("doctor")),
        ]
        let details = MoatClient(binary: self.binary, runner: runner).details()

        XCTAssertEqual(details.allowed.value?.rules.count, 3)
        XCTAssertEqual(details.secrets.value?.secrets.count, 4)
        XCTAssertEqual(details.checks.value?.problems, 1)
        XCTAssertEqual(runner.calls, [
            ["--version"],
            ["allowed", "--format", "json"],
            ["secret", "list", "--format", "json"],
            ["doctor", "--format", "json"],
        ])
    }

    func test_details_onAnOlderMoat_areNotesNotErrors() {
        let runner = StubRunner()
        runner.outputs = ["--version": .success(Data("moat 0.5.3 (OpenMoat)\n".utf8))]
        let details = MoatClient(binary: self.binary, runner: runner).details()

        let note = ScreenState<AllowedReport>.needsNewerMoat(note: MoatRequirement.note("0.5.5"))
        XCTAssertEqual(details.allowed, note)
        XCTAssertNil(details.secrets.value)
        XCTAssertEqual(runner.calls, [["--version"]], "commands moat lacks are not run")
    }

    // MARK: - Words and commands

    func test_endsIn_roundsUpToTheMinute() {
        let now: Int64 = 1_792_061_000_000
        XCTAssertEqual(DetailsText.endsIn(now + 11_400_000, nowMs: now), "Ends in 3 h 10 min")
        XCTAssertEqual(DetailsText.endsIn(now + 7_200_000, nowMs: now), "Ends in 2 h")
        XCTAssertEqual(DetailsText.endsIn(now + 30000, nowMs: now), "Ends in 1 min")
        XCTAssertEqual(DetailsText.endsIn(now - 1, nowMs: now), "Ended")
    }

    func test_takeBackCommands_matchMoatAllowed() {
        XCTAssertEqual(CopyCommands.removeRule("approved-1"), "moat allow --remove approved-1")
        XCTAssertEqual(CopyCommands.revokeTrust("/Users/you/code/app"), "moat trust --revoke /Users/you/code/app")
        XCTAssertEqual(
            CopyCommands.revokeTrust("/Users/you/code/team app"),
            "moat trust --revoke '/Users/you/code/team app'"
        )
        XCTAssertEqual(CopyCommands.policyUpgrade, "moat policy upgrade")
    }
}
