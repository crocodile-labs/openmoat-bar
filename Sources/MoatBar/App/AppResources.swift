import AppKit

/// Finds the app's images. In `MoatBar.app` they sit in `Contents/Resources`
/// (`Scripts/package_app.sh` copies them there); under `swift run` they are in
/// the SwiftPM resource bundle next to the binary. SwiftPM's own `Bundle.module`
/// is not used because it stops the app when the bundle is not where it expects.
enum AppResources {
    static func image(_ name: String) -> NSImage? {
        if let image = Bundle.main.image(forResource: name) {
            return image
        }
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("MoatBar_MoatBar.bundle"),
            Bundle.main.resourceURL?.appendingPathComponent("MoatBar_MoatBar.bundle"),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("MoatBar_MoatBar.bundle"),
        ]
        for url in candidates.compactMap({ $0 }) {
            if let image = Bundle(url: url)?.image(forResource: name) {
                return image
            }
        }
        return nil
    }

    private static var agentIcons: [String: NSImage] = [:]

    /// The agent's icon as a template image, or `nil` for an agent without one.
    /// Icons: CodexBar's provider icons and OpenClaw's lobster (MIT), see
    /// Resources/ICONS.md.
    static func agentIcon(_ host: String) -> NSImage? {
        let name: String
        switch host {
        case "claude-code": name = "agent-claude"
        case "codex": name = "agent-codex"
        case "cursor": name = "agent-cursor"
        case "openclaw": name = "agent-openclaw"
        case "copilot-cli": name = "agent-copilot"
        case "pi": name = "agent-pi"
        case "gemini-cli": name = "agent-gemini"
        default: return nil
        }
        if let cached = self.agentIcons[name] {
            return cached
        }
        guard let image = self.image(name) else {
            return nil
        }
        image.isTemplate = true
        self.agentIcons[name] = image
        return image
    }
}
