import Foundation
import XCTest
@testable import MoatBarCore

final class SnapshotTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func snapshot(_ status: String = "status") throws -> Snapshot {
        try Snapshot(
            status: Fixture.decode(StatusReport.self, status),
            events: Fixture.decode([Event].self, "show-today")
        )
    }

    func test_agentName_namesEveryAgentAndOpenMoatsOwnHosts() throws {
        let snapshot = try Snapshot(
            status: Fixture.decode(StatusReport.self, "status-hosts"),
            events: Fixture.decode([Event].self, "show-hosts")
        )

        XCTAssertEqual(snapshot.events.map { snapshot.agentName($0.host) }, [
            "Gemini CLI", "Network proxy", "MCP proxy", "openmoat run",
        ])
        XCTAssertEqual(snapshot.unprotected.map(\.host), ["gemini-cli"])
        XCTAssertEqual(snapshot.agent("gemini-cli")?.reason?.hasPrefix("hook turned off by"), true)
        XCTAssertEqual(
            snapshot.installedAgents.map(\.host),
            ["claude-code", "codex", "openclaw", "copilot-cli", "gemini-cli"]
        )
        XCTAssertEqual(snapshot.protectedCount, 3)
    }

    func test_counts_coverEveryVerdict() throws {
        let counts = try self.snapshot().counts()

        XCTAssertEqual(counts[.deny], 3)
        XCTAssertEqual(counts[.ask], 1)
        XCTAssertEqual(counts[.deferred], 1)
        XCTAssertEqual(counts[.allow], 3)
    }

    func test_counts_forOneAgent() throws {
        let counts = try self.snapshot().counts(for: "codex")

        XCTAssertEqual(counts[.deny], 1)
        XCTAssertEqual(counts[.deferred], 1)
        XCTAssertEqual(counts[.allow], 0, "every verdict has an entry")
    }

    func test_list_isNewestFirst() throws {
        let blocked = try self.snapshot().list(.deny)

        XCTAssertEqual(blocked.map(\.id), ["1e", "1c", "1b"])
    }

    func test_hourly_bucketsByLocalHour() throws {
        let hours = try self.snapshot().hourly(calendar: self.utc)

        // 1792054800000 ms is 09:00 UTC; the fixture spans 09:00 to 10:40.
        XCTAssertEqual(hours.count, 24)
        XCTAssertEqual(hours[9][.allow], 1)
        XCTAssertEqual(hours[9][.deny], 2)
        XCTAssertEqual(hours[10][.deny], 1)
        XCTAssertEqual(hours[10][.allow], 2)
        XCTAssertNil(hours[11][.allow])
    }

    func test_sessions_groupAndSortByLastActivity() throws {
        let sessions = try self.snapshot().sessions()

        XCTAssertEqual(sessions.map(\.id), ["s-cur", "s-moat", "s-app", "s-site"])
        let moat = try XCTUnwrap(sessions.first { $0.id == "s-moat" })
        XCTAssertEqual(moat.total, 3)
        XCTAssertEqual(moat.counts[.deny], 1)
        XCTAssertEqual(moat.cwd, "/Users/you/code/openmoat")
    }

    func test_topRules_countOnlyBlocksAndAsks() throws {
        let rules = try self.snapshot().topRules()

        XCTAssertEqual(rules, [
            RuleTally(rule: "secrets-paths", count: 2),
            RuleTally(rule: "destructive", count: 1),
            RuleTally(rule: "git-internals", count: 1),
        ])
    }

    func test_agents_protectedAndUnprotected() throws {
        let fine = try self.snapshot()
        XCTAssertEqual(fine.protectedCount, 2)
        XCTAssertEqual(fine.installedAgents.map(\.host), ["claude-code", "codex"])
        XCTAssertTrue(fine.unprotected.isEmpty)

        let broken = try self.snapshot("status-unprotected")
        XCTAssertEqual(broken.unprotected.map(\.host), ["claude-code"])
    }

    func test_lastCall_andNewestBlock() throws {
        let snapshot = try self.snapshot()

        XCTAssertEqual(snapshot.lastCall(for: "codex"), Date(timeIntervalSince1970: 1_792_059_000))
        XCTAssertNil(snapshot.lastCall(for: "nobody"))
        XCTAssertEqual(snapshot.newestBlockMs, 1_792_059_000_000)
    }
}
