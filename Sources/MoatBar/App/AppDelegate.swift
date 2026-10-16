import AppKit
import MoatBarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SnapshotStore()
    private let notifier = Notifier()
    private var statusItem: StatusItemController?
    private var watcher: AuditWatcher?

    func applicationDidFinishLaunching(_: Notification) {
        self.statusItem = StatusItemController(store: self.store)
        self.store.onSnapshot = { [weak self] old, new in
            self?.notifier.changed(from: old, to: new)
        }
        self.notifier.requestPermission()

        // New calls show up within seconds of moat writing them.
        let watcher = AuditWatcher { [weak self] in self?.store.refresh() }
        watcher.start()
        self.watcher = watcher

        self.store.start()
    }

    func applicationWillTerminate(_: Notification) {
        self.watcher?.stop()
        self.store.stop()
    }
}
