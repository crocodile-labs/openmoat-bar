import Foundation

/// Plain words for OpenMoat's rule ids, for the decision view. The rule ids
/// are the default policy's (openmoat `crates/openmoat-core/policies/default-v1.yaml`)
/// and the ones moat's guard, engine and proxy add themselves (`push.rs`, `mcp.rs`,
/// `guard/drift.rs`, `action.rs`, `crates/openmoat-proxy`);
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
        // `default.<kind>`: no rule named this call, so the policy's default for
        // its kind decided (`default.shell`, `default.fs.read`, `default.mcp`, ...).
        if rule.hasPrefix("default.") {
            return "No rule names this, so the policy's default for \(self.kindWords(rule)) decided."
        }
        return nil
    }

    /// `default.fs.read` → `reading files`.
    private static func kindWords(_ rule: String) -> String {
        let kind = String(rule.dropFirst("default.".count))
        return self.kinds[kind] ?? "this kind of call"
    }

    private static let kinds: [String: String] = [
        "shell": "commands", "fs.read": "reading files", "fs.write": "writing files", "net": "network",
        "fetch": "fetching pages", "web.search": "web searches", "tool.unknown": "unknown tools",
        "env.read": "reading variables", "env.set": "setting variables", "mcp": "MCP tools",
    ]

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
        "push-unchecked": "OpenMoat couldn't check what this push publishes, so it asks.",
        "token-egress": "A known kind of token was about to go to a host that isn't its own service.",
        "placeholder-egress": "A brokered secret's placeholder was about to go to a host that secret isn't for.",
        "mcp-server-changed":
            "This MCP server's definition changed since a person accepted it, "
            + "so its tools wait for openmoat mcp accept.",
        "mcp-tool-held": "This MCP tool's description or inputs changed, so it stays hidden until a person accepts it.",
        "settings-drift":
            "A settings file OpenMoat pinned changed in a way that changes no decision, so calls are decided as usual.",
        // The rest of the default policy (openmoat 0.10.0).
        "agent-folders": "Renaming or removing this folder would move agent settings that OpenMoat protects.",
        "stops-openmoat": "This would stop a running OpenMoat process, such as its network proxy.",
        "build-credentials":
            "Maven and Gradle settings files hold registry passwords. Agents never read them; builds still can.",
        "env-poison": "This changes how later commands find programs or load code, so it could run something else.",
        "cloud-metadata":
            "Cloud metadata and link-local services hand out the machine's cloud credentials to any caller.",
        "agent-temp": "The agent's own temporary files, which it writes and reads back.",
        "dev-readonly": "A read-only inspection tool, or a variable that holds no secret.",
        "shell-locals": "A shell's own variables, like the current directory or the prompt.",
        "dev-tools": "A development tool reading or writing its own files.",
        "text-tools": "A read-only text tool, like grep or sort, on files the agent may read.",
        "registries": "A package registry OpenMoat knows, like npm or crates.io.",
        "safe-mcp": "An MCP tool that only reads, on a server OpenMoat knows.",
        "persistence": "This would run again later, on its own, outside this session.",
        "home-sweep": "This reads your whole home folder, secrets included.",
        "other-home": "This names another user's home folder, which OpenMoat can't place.",
        "secret-names": "This names a secret's file in a folder OpenMoat can't see into.",
        "opaque-code": "A program OpenMoat can't read could open any file or variable.",
        "docker-secrets": "This hands secrets, the SSH agent or the host itself to a container build.",
        "local-net": "A local service, which may expose a control API like Docker's or a database's.",
        // Rules the guard, openmoat run and the proxy add themselves.
        "project-settings":
            "A project settings file changed in a way that could switch OpenMoat off or run a program, "
            + "so the change isn't loaded into this session.",
        "session-taint":
            "The agent read untrusted content earlier in this session, so what it does with it is asked about.",
        "config-change": "The agent changed its own host's settings, which OpenMoat records and checks.",
        "kernel-error": "OpenMoat hit an error while deciding, so it stopped the call rather than let it through.",
        "unparseable": "OpenMoat couldn't read this command well enough to judge it, so it asks.",
        "unchecked": "OpenMoat couldn't see all of this call, like input typed into a running shell, so it asks.",
        "ungoverned": "OpenMoat has no rules for this tool, so the agent's own permission flow decided.",
        "approved-session": "You allowed this call again for the rest of its session with openmoat allow.",
        "run-session": "This session runs under openmoat run, which links its calls to the proxy.",
        "run-guard-token": "A hook call came with the wrong token for this openmoat run, so it wasn't decided.",
        "executables": "The program isn't the one OpenMoat pinned at that path, so it stays stopped.",
        "mcp-proxy": "An MCP tool call that passed through OpenMoat's MCP proxy.",
        "proxy-address": "The proxy refused a connection to a local, link-local, metadata or unnamed address.",
        "proxy-sni": "The proxy refused a connection that hides the server's name, which it can't check.",
        "proxy-request": "The proxy refused a request it couldn't read or that broke its rules.",
        "proxy-upstream": "The proxy couldn't reach or trust the server it was asked for.",
        "proxy-secret": "The proxy stopped a brokered secret from going where it isn't meant to.",
        "proxy-session": "The proxy didn't know the session this request claims to come from.",
        "proxy-audit": "The proxy couldn't record the request in the audit log, so it refused it.",
        "proxy-port": "The site is allowed on the usual web ports, 443 and 80, but not on the port this asked for.",
        "proxy-capacity": "The proxy already had as many connections open as it allows, so it refused new ones.",
        "moat.cloud-metadata": "Cloud metadata services hand out the machine's cloud credentials; never fetched.",
    ]
}
