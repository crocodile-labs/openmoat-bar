import Foundation
import XCTest
@testable import MoatBarCore

final class SettingsMigrationTests: XCTestCase {
    func test_firstStart_copiesTheOldSettings() {
        let old: [String: Any] = ["notifyBlocks": true, "welcomed": true, "selectedHost": "codex", "other": 1]
        let out = SettingsMigration.values(old: old, current: [:])

        XCTAssertEqual(out["notifyBlocks"] as? Bool, true)
        XCTAssertEqual(out["welcomed"] as? Bool, true)
        XCTAssertEqual(out["selectedHost"] as? String, "codex")
        XCTAssertNil(out["other"], "only the app's own keys")
        XCTAssertEqual(out[SettingsMigration.doneKey] as? Bool, true)
    }

    func test_newSettings_winOverOldOnes() {
        let out = SettingsMigration.values(old: ["notifyBlocks": true], current: ["notifyBlocks": false])
        XCTAssertNil(out["notifyBlocks"])
        XCTAssertEqual(out[SettingsMigration.doneKey] as? Bool, true)
    }

    func test_noOldApp_onlyMarksDone() {
        let out = SettingsMigration.values(old: nil, current: [:])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[SettingsMigration.doneKey] as? Bool, true)
    }

    func test_afterTheFirstStart_nothingIsCopied() {
        let out = SettingsMigration.values(
            old: ["welcomed": true],
            current: [SettingsMigration.doneKey: true]
        )
        XCTAssertTrue(out.isEmpty)
    }
}
