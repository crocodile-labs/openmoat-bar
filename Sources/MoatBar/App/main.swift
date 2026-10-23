import AppKit

/// A menu bar app: no Dock icon, no main window.
let app = NSApplication.shared
// Settings saved under the old name, MoatBar, carry over before anything reads them.
Preferences.migrateFromMoatBar()
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
