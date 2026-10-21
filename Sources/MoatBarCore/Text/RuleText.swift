import Foundation

/// Plain words for OpenMoat's rule ids, for the decision view. The rule ids
/// are the default policy's (openmoat `crates/openmoat-core/policies/default-v1.yaml`)
/// and the ones moat's guard adds itself (`push.rs`, `mcp.rs`, `guard/drift.rs`);
/// a rule from a custom policy falls back to the reason moat gave the agent.
/// The desktop app has the same table in `desktop/src/core/Text.cpp`.
public enum RuleText {
    /// The rule id moat adds, after the deciding rule, to the first call of a
    /// session decided while a pinned settings file differs in ways that change
    /// no decision (openmoat `crates/openmoat-cli/src/commands/guard/drift.rs`).
    public static let settingsDrift = "settings-drift"

    /// Why a rule exists, in one sentence a non-expert can read.
    public static func why(_ rule: String) -> String? {
        if let words = self.table[rule] {
            return words
        }
        // `pack:<name>:<id>`: a rule from a signed policy pack (openmoat `packs.rs`).
        if rule.hasPrefix("pack:") {
            let name = rule.dropFirst("pack:".count).split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
            return name.isEmpty
                ? "A rule from a signed policy pack you installed."
                : "A rule from the policy pack \(name), installed after its signature checked out."
        }
        // `repo:<id>`: a rule from the project's `.moat/policy.yaml` (openmoat `repo.rs`).
        if rule.hasPrefix("repo:") {
            return "A rule from this repository's own OpenMoat policy file."
        }
        return nil
    }

    /// The note for a call decided while OpenMoat's settings had drifted;
    /// `nil` when moat didn't add one, or when it is the only rule (then
    /// `why` already says it).
    public static func driftNote(_ rules: [String]) -> String? {
        guard rules.first != self.settingsDrift, rules.contains(self.settingsDrift) else {
            return nil
        }
        return "A settings file OpenMoat pinned changed in a way that changes no decision. "
            + "openmoat doctor shows the change."
    }

    private static let table: [String: String] = [
        "secrets-paths":
            "Private keys, .env files and cloud credentials hold passwords and tokens. Agents never read them.",
        "destructive":
            "This throws away work that can't be brought back, like uncommitted changes or a home folder.",
        "pipe-to-shell": "Running a script straight from the internet means running code nobody has looked at.",
        "env-secrets": "Printing environment variables would show tokens to the agent and to whatever it talks to.",
        "env-dump": "Printing environment variables would show tokens to the agent and to whatever it talks to.",
        "shell-rc": "Changing your shell's startup files would run code in every terminal you open later.",
        "kernel-self": "Agents can't change OpenMoat's own rules, hooks or binary. Only a person can, in a terminal.",
        "kernel-integrity": "A file OpenMoat watches was changed outside OpenMoat, so calls stop until a person looks.",
        "git-internals": "This changes which hooks git runs, which would run code on later git commands.",
        "runs-later": "This changes something that runs on its own later, like CI settings or editor tasks.",
        "default.net": "The agent tried to reach a site that isn't on the allowed list.",
        "default": "No rule covers this, so the agent's own prompt decided.",
        "dev-shell": "A normal development command, like building or testing.",
        "project-fs": "Reading or writing files inside the project.",
        "package-near-miss":
            "The package name is one typo away from a popular one, a common trick for slipping in a look-alike.",
        "push-secret": "The push would publish a token or a brokered secret's value in a commit.",
        "push-runs-later":
            "After reading untrusted content, the agent pushes a change to a file CI runs with your secrets.",
        "push-unchecked": "OpenMoat couldn't check what this push publishes in time, so it asks.",
        "token-egress": "A known kind of token was about to go to a host that isn't its own service.",
        "placeholder-egress": "A brokered secret's placeholder was about to go to a host that secret isn't for.",
        "mcp-server-changed":
            "This MCP server's definition changed since a person accepted it, "
                + "so its tools wait for openmoat mcp accept.",
        "mcp-tool-held": "This MCP tool's description or inputs changed, so it stays hidden until a person accepts it.",
        "settings-drift":
            "A settings file OpenMoat pinned changed in a way that changes no decision, so calls are decided as usual.",
    ]
}
