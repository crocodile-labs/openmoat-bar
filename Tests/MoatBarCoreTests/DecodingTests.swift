import Foundation
import XCTest
@testable import MoatBarCore

final class DecodingTests: XCTestCase {
    func test_status_decodesEveryLevel() throws {
        let status = try Fixture.decode(StatusReport.self, "status")

        XCTAssertEqual(status.agents.map(\.host), ["claude-code", "codex", "cursor"])
        XCTAssertEqual(status.agents.map(\.level), [.hookAndOsSandbox, .hookOnly, .notFound])
        XCTAssertEqual(status.agents[1].reason, "the sandbox profile is older than the policy")
        XCTAssertNil(status.agents[0].reason)
    }

    func test_status_unknownLevel_isNeverProtected() throws {
        let status = try Fixture.decode(StatusReport.self, "status-unprotected")

        XCTAssertEqual(status.agents[2].level, .unknown)
        XCTAssertFalse(status.agents[2].level.isHooked)
    }

    func test_events_decodeActionsVerdictsAndHexIds() throws {
        let events = try Fixture.decode([Event].self, "show-today")

        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(events[0].id, "1a")
        XCTAssertEqual(events[0].action, .shell(command: "git status --short"))
        XCTAssertEqual(events[2].action, .fsRead(path: "/Users/you/.ssh/id_ed25519"))
        XCTAssertEqual(events[2].display, "Read /Users/you/.ssh/id_ed25519")
        XCTAssertEqual(events[3].verdict, .deferred)
        XCTAssertEqual(events[4].rule, "secrets-paths")
        XCTAssertEqual(events[4].reason, "secret material: read /Users/you/code/app/.env")
        XCTAssertEqual(events[6].action, .mcpTool(name: "mcp__github__get_issue"))
    }

    func test_events_withoutAction_showTheToolName() throws {
        let events = try Fixture.decode([Event].self, "show-today")

        XCTAssertNil(events[7].action)
        XCTAssertNil(events[7].cwd)
        XCTAssertEqual(events[7].display, "TodoWrite")
    }

    func test_events_fromOlderOrNewerMoat_stillDecode() throws {
        let events = try Fixture.decode([Event].self, "show-legacy")

        XCTAssertEqual(events[0].id, "1f", "integer ids become hex like moat prints them")
        XCTAssertEqual(events[0].verdict, .deferred, "an unknown verdict is never counted as allowed or blocked")
        XCTAssertEqual(events[0].display, "Patch 2 files")
        XCTAssertEqual(events[0].reasons, [])
        XCTAssertEqual(events[1].action, .other(kind: "frobnicate"))
    }

    func test_events_uncheckedAction_keepsWhatItShowsAndWhy() throws {
        let events = try Fixture.decode([Event].self, "show-unchecked")

        XCTAssertEqual(events[0].action, .unchecked(
            action: .shell(command: "npm test"),
            reason: "input typed into a running shell joins what was typed before, which this call does not show"
        ))
        XCTAssertEqual(events[0].display, "npm test")
        XCTAssertEqual(events[0].action?.uncheckedReason?.hasPrefix("input typed"), true)
        XCTAssertEqual(
            events[1].action?.shown,
            .readFiles(paths: ["/Users/you/code/api/src", "/Users/you/code/api/docs"])
        )
        XCTAssertEqual(events[1].display, "Read 2 files")
        XCTAssertEqual(events[2].action?.shown, .fsRead(path: "/Users/you/code/site/README.md"))
        XCTAssertNil(events[3].action?.uncheckedReason)
        XCTAssertEqual(events[4].action, .other(kind: "unchecked"), "without the action inside, only the kind shows")
    }

    func test_report_decodesRuleTuples() throws {
        let report = try Fixture.decode(Summary.self, "report-7d")

        XCTAssertEqual(report.total, 8421)
        XCTAssertEqual(report.deferred, 1350)
        XCTAssertEqual(report.byHost["codex"], 3301)
        XCTAssertEqual(report.topRules.first, Summary.RuleCount(rule: "secrets-paths", count: 22))
        XCTAssertEqual(report.activeHours, 41)
    }

    func test_proxy_decodesKnownAndUnknownStates() throws {
        XCTAssertEqual(try Fixture.decode(ProxyReport.self, "proxy-running").state, .running)
        XCTAssertEqual(
            try Fixture.decode(ProxyReport.self, "proxy-unknown").state,
            .unknown(details: "systemctl --user has no user bus")
        )
    }

    func test_action_roundTripsThroughJSON() throws {
        let actions: [Action] = [
            .shell(command: "ls"),
            .foreignShell(shell: "PowerShell", command: "Get-ChildItem"),
            .fsWrite(path: "a.txt"),
            .fetch(url: "https://docs.rs"),
            .webSearch(query: "swift"),
            .unknownTool(host: "cursor", tool: "Task"),
            .readFiles(paths: ["a", "b"]),
            .unchecked(action: .shell(command: "make"), reason: "typed into a running shell"),
        ]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            XCTAssertEqual(try JSONDecoder().decode(Action.self, from: data), action)
        }
    }
}
