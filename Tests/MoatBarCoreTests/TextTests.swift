import Foundation
import XCTest
@testable import MoatBarCore

final class TextTests: XCTestCase {
    func test_policyCheck_quotesTheCommand() {
        XCTAssertEqual(
            CopyCommands.policyCheck(.shell(command: "cat .env")),
            "moat policy check 'cat .env'"
        )
        XCTAssertEqual(
            CopyCommands.policyCheck(.shell(command: "echo 'hi'")),
            "moat policy check 'echo '\\''hi'\\'''"
        )
    }

    func test_policyCheck_addsTheKind() {
        XCTAssertEqual(
            CopyCommands.policyCheck(.fsRead(path: "~/.ssh/id_ed25519")),
            "moat policy check '~/.ssh/id_ed25519' --kind fs-read"
        )
        XCTAssertEqual(
            CopyCommands.policyCheck(.fetch(url: "https://docs.rs")),
            "moat policy check 'https://docs.rs' --kind fetch"
        )
        XCTAssertNil(CopyCommands.policyCheck(.patch(writes: ["a"])))
    }

    func test_ruleText_knowsTheDefaultRules() {
        for rule in ["secrets-paths", "destructive", "pipe-to-shell", "env-secrets", "kernel-self", "git-internals"] {
            XCTAssertNotNil(RuleText.why(rule), rule)
        }
        XCTAssertNil(RuleText.why("my-team-rule"))
    }

    func test_reportLink_carriesOnlyTheRule() {
        let url = DocsLink.reportWrongBlock(rule: "secrets-paths")

        XCTAssertEqual(url.host, "github.com")
        XCTAssertEqual(url.query, "title=False%20positive:%20secrets-paths")
    }
}
