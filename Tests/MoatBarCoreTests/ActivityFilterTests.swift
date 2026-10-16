import Foundation
import XCTest
@testable import MoatBarCore

final class ActivityFilterTests: XCTestCase {
    private func events() throws -> [Event] {
        try Fixture.decode([Event].self, "show-today")
    }

    func test_defaultsToBlocked_newestFirst() throws {
        XCTAssertEqual(try ActivityFilter().apply(self.events()).map(\.id), ["1e", "1c", "1b"])
    }

    func test_filtersByAgentVerdictAndRule() throws {
        let events = try self.events()

        XCTAssertEqual(ActivityFilter(host: "codex", verdict: nil).apply(events).map(\.id), ["1e", "1d"])
        XCTAssertEqual(ActivityFilter(verdict: .deny, rule: "secrets-paths").apply(events).map(\.id), ["1e", "1c"])
        XCTAssertEqual(ActivityFilter(host: nil, verdict: nil).apply(events).count, 8)
    }

    func test_windows_matchMoatSinceValues() {
        XCTAssertEqual(TimeWindow.allCases.map(\.rawValue), ["today", "7d", "30d"])
    }

    func test_eventsSince_passesTheWindow() throws {
        let runner = StubRunner()
        runner.outputs = try ["show": .success(Fixture.data("show-today"))]
        let client = MoatClient(binary: URL(fileURLWithPath: "/usr/local/bin/moat"), runner: runner)

        _ = try client.events(since: .sevenDays)

        XCTAssertEqual(runner.calls, [["show", "--since", "7d", "--format", "json"]])
    }
}
