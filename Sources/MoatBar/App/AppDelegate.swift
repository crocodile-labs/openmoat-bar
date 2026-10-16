import AppKit
import MoatBarCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SnapshotStore()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_: Notification) {
        self.statusItem = StatusItemController(store: self.store)
        self.store.start()
    }

    func applicationWillTerminate(_: Notification) {
        self.store.stop()
    }
}
