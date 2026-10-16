import AppKit
import MoatBarCore

/// Owns the menu bar item: draws the icon and rebuilds the menu from the
/// latest snapshot each time it opens.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: SnapshotStore
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var menuOpen = false
    /// New data arrived while the menu was open.
    private var rebuildPending = false
    /// The agent tab row's selection; kept across rebuilds.
    private let tabs = TabState(selected: nil)
    private let defaults = UserDefaults.standard
    /// Opens the Settings window.
    var onSettings: (() -> Void)?
    /// Opens the Activity window, filtered to a verdict or `nil` for everything.
    var onActivity: ((Verdict?) -> Void)?

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

    // The menu is never rebuilt while it is open: removing items under the
    // cursor closes whatever submenu the person is moving into. Data that
    // arrives while it is open is applied after it closes (CodexBar defers
    // parent rebuilds during menu tracking the same way).

    func menuWillOpen(_: NSMenu) {
        // Safe: AppKit has not started tracking yet.
        self.rebuild()
        self.menuOpen = true
        self.store.refresh()
    }

    func menuDidClose(_: NSMenu) {
        self.menuOpen = false
        if let newest = self.store.snapshot?.newestBlockMs {
            self.seenUntilMs = newest
        }
        self.updateIcon()
        if self.rebuildPending {
            self.rebuildPending = false
            // After the close animation, so the next open shows the new data.
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.closedRebuildDelay) { [weak self] in
                guard let self, !self.menuOpen else {
                    return
                }
                self.rebuild()
            }
        }
    }

    // MARK: - Updates

    /// Wait this long after the menu closes before rebuilding it.
    private static let closedRebuildDelay: TimeInterval = 0.35

    private func storeChanged() {
        self.updateIcon()
        if self.menuOpen {
            self.rebuildPending = true
        } else {
            // Prepare the closed menu so it opens with fresh data.
            self.rebuild()
        }
    }

    private func updateIcon() {
        let attention = self.store.snapshot.map { !SecurityChecks.needingAttention(SecurityChecks.from($0)).isEmpty }
        let state = IconState.decide(
            snapshot: self.store.snapshot,
            seenUntilMs: self.seenUntilMs,
            needsAttention: attention ?? false
        )
        self.statusItem.button?.image = IconRenderer.image(for: state)
        self.statusItem.button?.toolTip = state.accessibilityLabel
    }

    private func builder() -> MenuBuilder {
        MenuBuilder(
            snapshot: self.store.snapshot,
            error: self.store.error,
            selectedHost: self.validSelection(),
            onSelectHost: { [weak self] host in self?.selectHost(host) },
            onRefresh: { [weak self] in self?.store.refresh() },
            onSettings: { [weak self] in self?.onSettings?() },
            onActivity: { [weak self] verdict in self?.onActivity?(verdict) }
        )
    }

    private func rebuild() {
        self.tabs.selected = self.validSelection()
        self.builder().fill(self.menu, tabs: self.tabs)
    }

    /// A tab click: the tab row animates its selection in place and only the
    /// content below it is replaced, without implicit animations.
    private func selectHost(_ host: String?) {
        self.selectedHost = host
        if self.tabs.selected != host {
            self.tabs.selected = host
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if !self.builder().replaceContent(in: self.menu) {
            self.rebuild()
        }
        CATransaction.commit()
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
