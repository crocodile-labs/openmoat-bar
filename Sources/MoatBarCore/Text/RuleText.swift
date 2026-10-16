import Foundation

/// Plain words for OpenMoat's rule ids, for the decision view. The rule ids
/// are the default policy's (openmoat `crates/openmoat-core/policies/default-v1.yaml`);
/// a rule from a custom policy falls back to the reason moat gave the agent.
public enum RuleText {
    /// Why a rule exists, in one or two sentences a non-expert can read.
    public static func why(_ rule: String) -> String? {
        switch rule {
        case "secrets-paths":
            return "Private keys, .env files and cloud credentials hold passwords and tokens. Agents never read them."
        case "destructive":
            return "This throws away work that can't be brought back, like uncommitted changes or a home folder."
        case "pipe-to-shell":
            return "Running a script straight from the internet means running code nobody has looked at."
        case "env-secrets", "env-dump":
            return "Printing environment variables would show tokens to the agent and to whatever it talks to."
        case "shell-rc":
            return "Changing your shell's startup files would run code in every terminal you open later."
        case "kernel-self":
            return "Agents can't change OpenMoat's own rules, hooks or binary. Only a person can, in a terminal."
        case "kernel-integrity":
            return "A file OpenMoat watches was changed outside moat, so calls stop until a person looks."
        case "git-internals":
            return "This changes which hooks git runs, which would run code on later git commands."
        case "runs-later":
            return "This changes something that runs on its own later, like CI settings or editor tasks."
        case "default.net":
            return "The agent tried to reach a site that isn't on the allowed list."
        case "default":
            return "No rule covers this, so the agent's own prompt decided."
        case "dev-shell":
            return "A normal development command, like building or testing."
        case "project-fs":
            return "Reading or writing files inside the project."
        default:
            return nil
        }
    }
}
