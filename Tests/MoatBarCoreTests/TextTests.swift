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

    /// Every rule group in openmoat 0.9.0's `default-v1.yaml`, in its order.
    private let defaultPolicyRules = [
        "secrets-paths", "build-credentials", "env-secrets", "env-dump", "env-poison", "pipe-to-shell", "destructive",
        "kernel-self", "shell-rc", "cloud-metadata", "token-egress", "placeholder-egress",
        "project-fs", "agent-temp", "dev-shell", "dev-readonly", "shell-locals", "dev-tools", "text-tools",
        "registries", "safe-mcp",
        "git-internals", "runs-later", "persistence", "home-sweep", "other-home", "secret-names", "opaque-code",
        "package-near-miss", "docker-secrets", "local-net",
    ]

    /// The ids the guard, `openmoat run` and the proxy add themselves.
    private let builtInRules = [
        "kernel-integrity", "kernel-error", "unparseable", "ungoverned", "settings-drift", "config-change",
        "session-taint", "approved-session", "run-session", "run-guard-token", "project-settings", "executables",
        "push-secret", "push-runs-later", "push-unchecked", "mcp-server-changed", "mcp-tool-held", "mcp-proxy",
        "proxy-address", "proxy-sni", "proxy-request", "proxy-upstream", "proxy-secret", "proxy-session",
        "proxy-audit", "moat.cloud-metadata", "default",
    ]

    func test_ruleText_knowsTheDefaultRules() {
        for rule in self.defaultPolicyRules + self.builtInRules {
            let why = RuleText.why(rule)
            XCTAssertNotNil(why, rule)
            XCTAssertEqual(why?.contains("\n"), false, "one line: \(rule)")
        }
        XCTAssertNil(RuleText.why("my-team-rule"))
    }

    func test_ruleText_namesTheKindBehindADefaultRule() {
        XCTAssertEqual(
            RuleText.why("default.fs.read"),
            "No rule names this, so the policy's default for reading files decided."
        )
        XCTAssertEqual(
            RuleText.why("default.mcp"),
            "No rule names this, so the policy's default for MCP tools decided."
        )
        XCTAssertEqual(RuleText.why("default.net"), "The agent tried to reach a site that isn't on the allowed list.")
        XCTAssertEqual(
            RuleText.why("default.something-new"),
            "No rule names this, so the policy's default for this kind of call decided."
        )
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

    func test_hostText_shortensTabTitles_andNamesOpenMoatsOwnHosts() throws {
        let status = try Fixture.decode(StatusReport.self, "status-hosts")

        XCTAssertEqual(status.agents.map(\.host), [
            "claude-code", "codex", "cursor", "openclaw", "copilot-cli", "pi", "gemini-cli",
        ])
        XCTAssertEqual(
            status.agents.map { HostText.short($0.name) },
            ["Claude", "Codex", "Cursor", "OpenClaw", "Copilot", "pi", "Gemini"]
        )
        XCTAssertEqual(HostText.name(forOther: "proxy"), "Network proxy")
        XCTAssertEqual(HostText.name(forOther: "mcp-proxy"), "MCP proxy")
        XCTAssertEqual(HostText.name(forOther: "moat-run"), "openmoat run")
        XCTAssertEqual(HostText.name(forOther: "a-host-from-the-future"), "a-host-from-the-future")
    }

    /// `rule-ids.json` lists every rule id of OpenMoat 0.10.0's default policy
    /// (`default-v1.yaml`) and the ones OpenMoat adds itself.
    func test_ruleText_explainsEveryRuleOfOpenMoat010() throws {
        struct RuleIds: Decodable {
            var defaultPolicy: [String]
            var addedByOpenmoat: [String]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let ids = try decoder.decode(RuleIds.self, from: Fixture.data("rule-ids"))

        XCTAssertEqual(ids.defaultPolicy.count, 33)
        for rule in ids.defaultPolicy + ids.addedByOpenmoat {
            let why = RuleText.why(rule)
            XCTAssertNotNil(why, rule)
            XCTAssertEqual(why?.contains("\n"), false, "one line: \(rule)")
        }
        XCTAssertEqual(RuleText.why("push-unchecked"), "OpenMoat couldn't check what this push publishes, so it asks.")
    }

    func test_policyCheck_ofAnUncheckedCall_checksWhatItShows() {
        let typed = Action.unchecked(action: .shell(command: "npm test"), reason: "typed into a running shell")

        XCTAssertEqual(CopyCommands.policyCheck(typed), "openmoat policy check 'npm test'")
        XCTAssertEqual(typed.shellCommand, "npm test")
        XCTAssertEqual(typed.display, "npm test")
        XCTAssertEqual(
            CopyCommands.policyCheck(.unchecked(action: .fsRead(path: "/p/a"), reason: "a glob")),
            "openmoat policy check '/p/a' --kind fs-read"
        )
        XCTAssertNil(CopyCommands.policyCheck(.unchecked(action: .readFiles(paths: ["a", "b"]), reason: "")))
    }

    func test_hostText_namesTheContinueCli() {
        XCTAssertEqual(HostText.name(forOther: "continue"), "Continue CLI")
    }

    func test_docsLinks_pointAtTheDocsPages() {
        let pages = [
            DocsLink.blocked, DocsLink.checkACommand, DocsLink.quickstart, DocsLink.troubleshooting,
            DocsLink.limits, DocsLink.howItDecides, DocsLink.mcpServers, DocsLink.allowReference,
            DocsLink.keepTokensSafe, DocsLink.turnOff,
        ]
        // The pages of openmoat.dev's docs as of OpenMoat 0.10.0.
        XCTAssertEqual(pages.map { $0.absoluteString.replacingOccurrences(of: "https://openmoat.dev", with: "") }, [
            "/docs/blocked/", "/docs/check-a-command/", "/docs/quickstart/", "/docs/troubleshooting/",
            "/docs/limits/", "/docs/how-it-decides/", "/docs/mcp-servers/", "/docs/allow-reference/",
            "/docs/keep-tokens-safe/", "/docs/turn-off/",
        ])
    }

    func test_reportLink_carriesOnlyTheRule() {
        let url = DocsLink.reportWrongBlock(rule: "secrets-paths")

        XCTAssertEqual(url.host, "github.com")
        XCTAssertEqual(url.query, "title=False%20positive:%20secrets-paths")
    }
}
