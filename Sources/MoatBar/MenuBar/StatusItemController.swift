import AppKit
import MoatBarCore

/// Owns the menu bar item: draws the icon and rebuilds the menu from the
/// latest snapshot each time it opens.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: SnapshotStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var menuOpen = false
    private let defaults = UserDefaults.standard
    /// Opens the Settings window.
    var onSettings: (() -> Void)?

    private enum Key {
        static let seenUntil = "seenUntilMs"
        static let selectedHost = "selectedHost"
    }

    /// The agent tab, or `nil` for all agents.
    private var selectedHost: String? {
        get { self.defaults.string(forKey: Key.selectedHost) }
        set { self.defaults.set(newValue, forKey: Key.selectedHost) }
    }

    /// The newest event time the person has seen in the open menu.
    private var seenUntilMs: Int64? {
        get { (self.defaults.object(forKey: Key.seenUntil) as? NSNumber)?.int64Value }
        set { self.defaults.set(newValue.map { NSNumber(value: $0) }, forKey: Key.seenUntil) }
    }

    init(store: SnapshotStore) {
        self.store = store
        super.init()
        self.menu.delegate = self
        self.menu.autoenablesItems = false
        self.statusItem.menu = self.menu
        self.statusItem.button?.imagePosition = .imageOnly
        store.onChange = { [weak self] in self?.storeChanged() }
        self.updateIcon()
    }

    /// Drop the menu as if the croc was clicked.
    func openMenu() {
        self.statusItem.button?.performClick(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_: NSMenu) {
        self.menuOpen = true
        self.rebuild()
        self.store.refresh()
    }

    func menuDidClose(_: NSMenu) {
        self.menuOpen = false
        if let newest = self.store.snapshot?.newestBlockMs {
            self.seenUntilMs = newest
        }
        self.updateIcon()
    }

    // MARK: - Updates

    private func storeChanged() {
        self.updateIcon()
        if self.menuOpen {
            self.rebuild()
        }
    }

    private func updateIcon() {
        let state = IconState.decide(snapshot: self.store.snapshot, seenUntilMs: self.seenUntilMs)
        self.statusItem.button?.image = IconRenderer.image(for: state)
        self.statusItem.button?.toolTip = state.accessibilityLabel
    }

    private func rebuild() {
        let builder = MenuBuilder(
            snapshot: self.store.snapshot,
            error: self.store.error,
            selectedHost: self.validSelection(),
            onSelectHost: { [weak self] host in
                self?.selectedHost = host
                self?.rebuild()
            },
            onRefresh: { [weak self] in self?.store.refresh() },
            onSettings: { [weak self] in self?.onSettings?() }
        )
        builder.fill(self.menu)
    }

    /// Forget a tab whose agent is no longer installed.
    private func validSelection() -> String? {
        guard let host = self.selectedHost else {
            return nil
        }
        if let snapshot = self.store.snapshot, snapshot.installedAgents.contains(where: { $0.host == host }) {
            return host
        }
        return nil
    }
}
