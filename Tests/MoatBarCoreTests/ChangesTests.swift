import Foundation
import XCTest

@testable import MoatBarCore

final class ChangesTests: XCTestCase {
    private func snapshot(_ status: String, events: Int) throws -> Snapshot {
        let all = try Fixture.decode([Event].self, "show-today")
        return try Snapshot(status: Fixture.decode(StatusReport.self, status), events: Array(all.prefix(events)))
    }

    func test_firstRead_reportsEveryUnprotectedAgentOnce() throws {
        let now = try self.snapshot("status-unprotected", events: 8)

        XCTAssertEqual(Changes.newlyUnprotected(from: nil, to: now).map(\.host), ["claude-code"])
        XCTAssertEqual(Changes.newlyUnprotected(from: now, to: now).count, 0)
    }

    func test_drop_isReportedWhenItHappens() throws {
        let before = try self.snapshot("status", events: 8)
        let after = try self.snapshot("status-unprotected", events: 8)

        XCTAssertEqual(Changes.newlyUnprotected(from: before, to: after).map(\.host), ["claude-code"])
        XCTAssertEqual(Changes.newlyUnprotected(from: after, to: before).count, 0, "a fix is not a notification")
    }

    func test_newBlocks_onlyAfterTheFirstRead() throws {
        let early = try self.snapshot("status", events: 2)
        let later = try self.snapshot("status", events: 8)

        XCTAssertEqual(Changes.newBlocks(from: nil, to: later), [])
        XCTAssertEqual(Changes.newBlocks(from: early, to: later).map(\.id), ["1c", "1e"])
        XCTAssertEqual(Changes.newBlocks(from: later, to: later), [])
    }

    func test_moatHome_followsMoatHomeVariable() {
        XCTAssertEqual(MoatHome.directory(environment: ["HOME": "/Users/you"]).path, "/Users/you/.moat")
        XCTAssertEqual(MoatHome.directory(environment: ["MOAT_HOME": "/tmp/m", "HOME": "/Users/you"]).path, "/tmp/m")
        XCTAssertEqual(
            MoatHome.auditFiles(in: URL(fileURLWithPath: "/x")).map(\.lastPathComponent),
            ["audit.db", "audit.db-wal"]
        )
    }
}
