import Foundation
import XCTest
@testable import MoatBarCore

final class TextTests: XCTestCase {
    func test_policyCheck_quotesTheCommand() {
        XCTAssertEqual(
            CopyCommands.policyCheck(.shell(command: "cat .env")),
            "openmoat policy check 'cat .env'"
        )
        XCTAssertEqual(
            CopyCommands.policyCheck(.shell(command: "echo 'hi'")),
            "openmoat policy check 'echo '\\''hi'\\'''"
        )
    }

    func test_policyCheck_addsTheKind() {
        XCTAssertEqual(
            CopyCommands.policyCheck(.fsRead(path: "~/.ssh/id_ed25519")),
            "openmoat policy check '~/.ssh/id_ed25519' --kind fs-read"
        )
        XCTAssertEqual(
            CopyCommands.policyCheck(.fetch(url: "https://docs.rs")),
            "openmoat policy check 'https://docs.rs' --kind fetch"
        )
        XCTAssertNil(CopyCommands.policyCheck(.patch(writes: ["a"])))
    }

    func test_ruleText_knowsTheDefaultRules() {
        for rule in ["secrets-paths", "destructive", "pipe-to-shell", "env-secrets", "kernel-self", "git-internals"] {
            XCTAssertNotNil(RuleText.why(rule), rule)
        }
        XCTAssertNil(RuleText.why("my-team-rule"))
    }

    func test_ruleText_explainsTheRulesMoatAdded() throws {
        let events = try Fixture.decode([Event].self, "show-new-rules")
        let rules = events.compactMap(\.rule)

        XCTAssertEqual(rules, [
            "package-near-miss",
            "push-secret",
            "token-egress",
            "mcp-server-changed",
            "dev-shell",
            "pack:team:no-deploy",
        ])
        for rule in rules {
            let why = try XCTUnwrap(RuleText.why(rule), rule)
            XCTAssertFalse(why.contains("\n"), "one line: \(rule)")
        }
        XCTAssertEqual(
            RuleText.why("pack:team:no-deploy"),
            "A rule from the policy pack team, installed after its signature checked out."
        )
        XCTAssertNotNil(RuleText.why("repo:no-prod"))
        XCTAssertNotNil(RuleText.why(RuleText.settingsDrift))
    }

    func test_ruleText_notesSettingsDrift_onlyBesideAnotherRule() throws {
        let events = try Fixture.decode([Event].self, "show-new-rules")
        let drifted = try XCTUnwrap(events.first { $0.rules.contains(RuleText.settingsDrift) })

        XCTAssertEqual(drifted.rule, "dev-shell")
        XCTAssertEqual(RuleText.driftNote(drifted.rules)?.hasPrefix("A settings file OpenMoat pinned changed"), true)
        XCTAssertNil(RuleText.driftNote(["settings-drift"]), "the Why line already says it")
        XCTAssertNil(RuleText.driftNote(["dev-shell"]))
        XCTAssertTrue(events.filter { $0.id != drifted.id }.allSatisfy { RuleText.driftNote($0.rules) == nil })
    }

    func test_reportLink_carriesOnlyTheRule() {
        let url = DocsLink.reportWrongBlock(rule: "secrets-paths")

        XCTAssertEqual(url.host, "github.com")
        XCTAssertEqual(url.query, "title=False%20positive:%20secrets-paths")
    }
}
