import Foundation

/// Names for the hosts in moat's output: the agents `openmoat status` lists
/// (`claude-code`, `codex`, `cursor`, `openclaw`, `copilot-cli`, `pi`,
/// `gemini-cli`; openmoat `crates/openmoat-hosts/src/lib.rs`) and the other
/// hosts an audit event can carry. The desktop app has the same words in
/// `desktop/src/core/Text.cpp`.
public enum HostText {
    /// The tab title: the agent's display name without a trailing `Code` or
    /// `CLI`, so every tab fits in one row. `Claude Code` → `Claude`,
    /// `GitHub Copilot CLI` → `Copilot`, `Gemini CLI` → `Gemini`.
    public static func short(_ name: String) -> String {
        self.shortNames[name] ?? name
    }

    /// What to call an event's host when `openmoat status` lists no agent for
    /// it: OpenMoat's own parts write events too (`proxy`, `mcp-proxy`,
    /// `moat-run`; openmoat `crates/openmoat-audit/src/store.rs`). A host
    /// MoatBar doesn't know shows as its id.
    public static func name(forOther host: String) -> String {
        self.otherNames[host] ?? host
    }

    private static let shortNames: [String: String] = [
        "Claude Code": "Claude",
        "GitHub Copilot CLI": "Copilot",
        "Gemini CLI": "Gemini",
    ]

    private static let otherNames: [String: String] = [
        "proxy": "Network proxy",
        "mcp-proxy": "MCP proxy",
        "moat-run": "openmoat run",
    ]
}
