import Foundation
import XCTest
@testable import MoatBarCore

final class IconStateTests: XCTestCase {
    private func snapshot(_ status: String) throws -> Snapshot {
        try Snapshot(
            status: Fixture.decode(StatusReport.self, status),
            events: Fixture.decode([Event].self, "show-today")
        )
    }

    func test_noSnapshot_isUnavailable() {
        XCTAssertEqual(IconState.decide(snapshot: nil, seenUntilMs: nil), .unavailable)
    }

    func test_lostProtection_winsOverEverything() throws {
        let state = try IconState.decide(
            snapshot: self.snapshot("status-unprotected"),
            seenUntilMs: nil,
            needsAttention: true
        )
        XCTAssertEqual(state, .unprotected)
    }

    func test_attention_winsOverNewBlocks() throws {
        let state = try IconState.decide(snapshot: self.snapshot("status"), seenUntilMs: nil, needsAttention: true)
        XCTAssertEqual(state, .attention)
    }

    func test_unseenBlock_showsTheDot() throws {
        let state = try IconState.decide(snapshot: self.snapshot("status"), seenUntilMs: 1_792_056_000_000)
        XCTAssertEqual(state, .newBlocks)
    }

    func test_everythingSeen_isQuiet() throws {
        let state = try IconState.decide(snapshot: self.snapshot("status"), seenUntilMs: 1_792_059_000_000)
        XCTAssertEqual(state, .quiet)
    }

    func test_order() {
        XCTAssertEqual(IconState.allCases.sorted(), [.unavailable, .quiet, .newBlocks, .attention, .unprotected])
    }
}
