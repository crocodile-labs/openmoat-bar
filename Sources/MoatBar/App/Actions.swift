import AppKit

/// The only things MoatBar does besides showing: copy text and open a link.
enum Actions {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// The standard About panel with the MoatBar icon and one line on what it is.
    static func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: NSAttributedString(
                string: "Shows what OpenMoat does for your coding agents. Read-only: it never changes a rule.",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]
            ),
        ]
        if let icon = AppResources.image("AppIcon") ?? AppResources.image("logo-float") {
            options[.applicationIcon] = icon
        }
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleName") == nil {
            options[.applicationName] = "MoatBar"
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}

/// A menu item that runs a closure. Keeps menu building free of selectors.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(self.fire), keyEquivalent: key)
        self.target = self
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func fire() {
        self.handler()
    }
}
