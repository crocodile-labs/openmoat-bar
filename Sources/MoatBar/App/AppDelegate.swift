import AppKit
import MoatBarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences.shared
    private let store = SnapshotStore()
    private lazy var notifier = Notifier(preferences: self.preferences)
    private var statusItem: StatusItemController?
    private var watcher: AuditWatcher?
    private let welcomeWindow = WindowPresenter()
    private let settingsWindow = WindowPresenter()

    func applicationDidFinishLaunching(_: Notification) {
        let statusItem = StatusItemController(store: self.store)
        statusItem.onSettings = { [weak self] in self?.showSettings() }
        self.statusItem = statusItem

        self.store.onSnapshot = { [weak self] old, new in
            self?.notifier.changed(from: old, to: new)
        }
        self.notifier.requestPermission()

        // New calls show up within seconds of moat writing them.
        let watcher = AuditWatcher { [weak self] in self?.store.refresh() }
        watcher.start()
        self.watcher = watcher

        self.store.start()

        if !self.preferences.welcomed {
            self.showWelcome()
        }
    }

    func applicationWillTerminate(_: Notification) {
        self.watcher?.stop()
        self.store.stop()
    }

    // MARK: - Windows

    private func showWelcome() {
        let view = WelcomeView(
            preferences: self.preferences,
            onOpenMenu: { [weak self] in
                self?.preferences.welcomed = true
                self?.welcomeWindow.close()
                self?.statusItem?.openMenu()
            },
            onQuit: { NSApp.terminate(nil) }
        )
        self.welcomeWindow.show(title: "Welcome to MoatBar", size: NSSize(width: 460, height: 520), content: view)
    }

    private func showSettings() {
        let view = SettingsView(
            preferences: self.preferences,
            moatPath: MoatClient.locate()?.path,
            moatVersion: self.store.snapshot?.moatVersion
        )
        self.settingsWindow.show(title: "MoatBar Settings", size: NSSize(width: 460, height: 420), content: view)
    }
}
