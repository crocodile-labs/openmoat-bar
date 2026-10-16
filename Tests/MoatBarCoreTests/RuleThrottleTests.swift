import Foundation
import XCTest
@testable import MoatBarCore

final class RuleThrottleTests: XCTestCase {
    func test_oncePerRulePerPeriod() {
        var throttle = RuleThrottle(period: 600)
        let start = Date(timeIntervalSince1970: 0)

        XCTAssertTrue(throttle.allow("secrets-paths", now: start))
        XCTAssertFalse(throttle.allow("secrets-paths", now: start.addingTimeInterval(599)))
        XCTAssertTrue(throttle.allow("destructive", now: start.addingTimeInterval(1)), "rules are counted apart")
        XCTAssertTrue(throttle.allow("secrets-paths", now: start.addingTimeInterval(600)))
    }
}
