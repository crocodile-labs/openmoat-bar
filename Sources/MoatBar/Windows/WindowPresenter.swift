import AppKit
import SwiftUI

/// Shows a SwiftUI view in a small window, reusing it if already open.
final class WindowPresenter {
    private var window: NSWindow?

    func show(title: String, size: NSSize, content: some View, resizable: Bool = false) {
        if let window = self.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: resizable ? [.titled, .closable, .resizable, .miniaturizable] : [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        self.window?.close()
    }
}
