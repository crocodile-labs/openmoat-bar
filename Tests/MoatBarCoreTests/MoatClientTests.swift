import Foundation
import XCTest
@testable import MoatBarCore

final class MoatClientTests: XCTestCase {
    private let binary = URL(fileURLWithPath: "/opt/homebrew/bin/moat")

    func test_snapshot_readsStatusEventsProxyAndVersion() throws {
        let runner = StubRunner()
        runner.outputs = try [
            "status": .success(Fixture.data("status")),
            "show": .success(Fixture.data("show-today")),
            "proxy": .success(Fixture.data("proxy-running")),
            "--version": .success(Data("moat 0.5.3 (OpenMoat)\n".utf8)),
        ]
        let client = MoatClient(binary: self.binary, runner: runner)

        let snapshot = try client.snapshot(now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(snapshot.status.agents.count, 3)
        XCTAssertEqual(snapshot.events.count, 8)
        XCTAssertEqual(snapshot.proxy, .running)
        XCTAssertEqual(snapshot.moatVersion, "0.5.3")
        XCTAssertEqual(runner.calls, [
            ["status", "--format", "json"],
            ["show", "--since", "today", "--format", "json"],
            ["proxy", "status", "--format", "json"],
            ["--version"],
        ])
    }

    func test_snapshot_withoutProxyOrVersion_stillWorks() throws {
        let runner = StubRunner()
        runner.outputs = try [
            "status": .success(Fixture.data("status")),
            "show": .success(Fixture.data("show-today")),
        ]
        let snapshot = try MoatClient(binary: self.binary, runner: runner).snapshot()

        XCTAssertNil(snapshot.proxy)
        XCTAssertNil(snapshot.moatVersion)
    }

    func test_version_readsTheNewAndTheOldName() throws {
        let runner = StubRunner()
        runner.outputs = ["--version": .success(Data("openmoat 0.9.0 (OpenMoat)\n".utf8))]
        XCTAssertEqual(try MoatClient(binary: self.binary, runner: runner).version(), "0.9.0")

        runner.outputs = ["--version": .success(Data("moat 0.5.3 (OpenMoat)\n".utf8))]
        XCTAssertEqual(try MoatClient(binary: self.binary, runner: runner).version(), "0.5.3")
    }

    func test_statusFailure_failsTheSnapshot() {
        let runner = StubRunner()
        runner.outputs = ["status": .failure(.timedOut(command: "status --format json"))]

        XCTAssertThrowsError(try MoatClient(binary: self.binary, runner: runner).snapshot()) { error in
            XCTAssertEqual(error as? MoatError, .timedOut(command: "status --format json"))
        }
    }

    func test_textInsteadOfJSON_isUnreadable() {
        let runner = StubRunner()
        runner.outputs = ["status": .success(Data("Claude Code: hook + OS sandbox\n".utf8))]

        XCTAssertThrowsError(try MoatClient(binary: self.binary, runner: runner).status()) { error in
            XCTAssertEqual(error as? MoatError, .unreadable(command: "status"))
        }
    }

    func test_onlyReadOnlyCommandsAreAllowed() {
        XCTAssertEqual(MoatClient.allowedCommands.map { $0[0] }, [
            "status", "show", "report", "proxy", "--version", "allowed", "secret", "doctor",
        ])
        for line in [
            ["status", "--format", "json"],
            ["show", "--since", "7d", "--format", "json"],
            ["report", "--since", "today", "--format", "json"],
            ["proxy", "status", "--format", "json"],
            ["--version"],
            ["allowed", "--format", "json"],
            ["secret", "list", "--format", "json"],
            ["doctor", "--format", "json"],
        ] {
            XCTAssertTrue(MoatClient.isAllowed(line), line.joined(separator: " "))
        }
        for writer in [
            ["allow", "--last"],
            ["allow", "--remove", "approved-1"],
            ["trust", "--revoke", "/repo"],
            ["secret", "add", "gh"],
            ["secret", "list", "--format", "json", "gh"],
            ["doctor"],
            ["doctor", "--accept"],
            ["doctor", "--format", "json", "--accept"],
            ["proxy"],
            ["proxy", "install"],
            ["policy", "upgrade"],
            ["init"],
            ["uninstall"],
            ["edit"],
        ] {
            XCTAssertFalse(MoatClient.isAllowed(writer), writer.joined(separator: " "))
        }
    }

    func test_locate_prefersOpenmoatOverMoat_onPathThenKnownPlaces() {
        let env = ["PATH": "/usr/bin:/custom/bin", "HOME": "/Users/you"]

        let onPath = MoatClient.locate(environment: env) { $0 == "/custom/bin/openmoat" }
        XCTAssertEqual(onPath?.path, "/custom/bin/openmoat")

        let cargo = MoatClient.locate(environment: env) { $0 == "/Users/you/.cargo/bin/openmoat" }
        XCTAssertEqual(cargo?.path, "/Users/you/.cargo/bin/openmoat")

        // An install from before the rename has only `moat`.
        let older = MoatClient.locate(environment: env) { $0 == "/custom/bin/moat" }
        XCTAssertEqual(older?.path, "/custom/bin/moat")

        // openmoat anywhere beats a leftover moat earlier on PATH.
        let both = ["/custom/bin/moat", "/Users/you/.cargo/bin/openmoat"]
        let found = MoatClient.locate(environment: env) { both.contains($0) }
        XCTAssertEqual(found?.path, "/Users/you/.cargo/bin/openmoat")

        XCTAssertNil(MoatClient.locate(environment: env) { _ in false })
    }

    func test_processRunner_returnsOutputAndReportsFailures() throws {
        let sh = URL(fileURLWithPath: "/bin/sh")
        let runner = ProcessRunner()

        let out = try runner.run(sh, arguments: ["-c", "printf hello"], timeout: 5)
        XCTAssertEqual(String(bytes: out, encoding: .utf8), "hello")

        let failing = ["-c", "echo 'moat: no audit log' >&2; exit 3"]
        XCTAssertThrowsError(try runner.run(sh, arguments: failing, timeout: 5)) {
            XCTAssertEqual($0 as? MoatError, .failed(command: "-c", message: "no audit log"))
        }
    }

    func test_processRunner_acceptsListedExitCodesOnlyWithOutput() throws {
        let sh = URL(fileURLWithPath: "/bin/sh")
        let runner = ProcessRunner()

        let printed = ["-c", "printf '{}'; exit 64"]
        let out = try runner.run(sh, arguments: printed, timeout: 5, okExitCodes: [0, 64])
        XCTAssertEqual(String(bytes: out, encoding: .utf8), "{}")
        XCTAssertThrowsError(try runner.run(sh, arguments: printed, timeout: 5), "64 fails by default")

        let silent = ["-c", "echo 'moat: no policy' >&2; exit 64"]
        XCTAssertThrowsError(try runner.run(sh, arguments: silent, timeout: 5, okExitCodes: [0, 64])) {
            XCTAssertEqual($0 as? MoatError, .failed(command: "-c", message: "no policy"))
        }
    }

    func test_processRunner_stopsAtTheDeadline() {
        let start = Date()
        XCTAssertThrowsError(
            try ProcessRunner().run(URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.3)
        ) {
            XCTAssertEqual($0 as? MoatError, .timedOut(command: "5"))
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func test_processRunner_missingBinary_isNotInstalled() {
        XCTAssertThrowsError(
            try ProcessRunner().run(URL(fileURLWithPath: "/nonexistent/moat"), arguments: ["status"], timeout: 1)
        ) {
            XCTAssertEqual($0 as? MoatError, .notInstalled)
        }
    }
}
