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
    private let activityWindow = WindowPresenter()
    private let activity = ActivityModel()
    private let detailsWindow = WindowPresenter()
    private let details = DetailsModel()

    func applicationDidFinishLaunching(_: Notification) {
        let statusItem = StatusItemController(store: self.store)
        statusItem.onSettings = { [weak self] in self?.showSettings() }
        statusItem.onActivity = { [weak self] verdict in self?.showActivity(verdict) }
        statusItem.onDetails = { [weak self] tab in self?.showDetails(tab) }
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
        self.welcomeWindow.show(title: "Welcome to OpenMoat Bar", size: NSSize(width: 460, height: 520), content: view)
    }

    /// Open the Activity window, filtered to `verdict` (`nil` for everything).
    private func showActivity(_ verdict: Verdict?) {
        self.activity.filter.verdict = verdict
        self.activity.selectedID = nil
        self.activity.load()
        self.activityWindow.show(
            title: "OpenMoat Bar Activity",
            size: NSSize(width: 1040, height: 640),
            content: ActivityView(model: self.activity),
            resizable: true
        )
    }

    /// Open the Details window on `tab`: what you allowed, secrets or checks.
    private func showDetails(_ tab: DetailsTab) {
        self.details.tab = tab
        if let snapshot = self.store.snapshot {
            self.details.agentNames = Dictionary(
                snapshot.status.agents.map { ($0.host, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            self.details.updateNoticesNote = MoatRequirement.updateNoticesNote(for: snapshot.status)
        }
        self.details.load()
        self.detailsWindow.show(
            title: "OpenMoat Bar Details",
            size: NSSize(width: 620, height: 600),
            content: DetailsView(model: self.details),
            resizable: true
        )
    }

    private func showSettings() {
        let view = SettingsView(
            preferences: self.preferences,
            moatPath: MoatClient.locate()?.path,
            moatVersion: self.store.snapshot?.moatVersion
        )
        self.settingsWindow.show(title: "OpenMoat Bar Settings", size: NSSize(width: 460, height: 420), content: view)
    }
}
