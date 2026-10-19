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
