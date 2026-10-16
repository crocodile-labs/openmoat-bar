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
        self.warmTabs()
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

    private func builder(host: String?) -> MenuBuilder {
        MenuBuilder(
            snapshot: self.store.snapshot,
            error: self.store.error,
            selectedHost: host,
            onSelectHost: { [weak self] host in self?.selectHost(host) },
            onRefresh: { [weak self] in self?.store.refresh() },
            onSettings: { [weak self] in self?.onSettings?() },
            onActivity: { [weak self] verdict in self?.onActivity?(verdict) }
        )
    }

    private func rebuild() {
        self.contentCache = [:]
        self.shownTab = Self.cacheKey(self.validSelection())
        self.builder(host: self.validSelection()).fill(self.menu)
    }

    // MARK: - Tab switching

    // Like CodexBar's switcher: every tab's content is built ahead of time while
    // the menu is open, one tab per run loop turn, and a click swaps the ready
    // items in. The outgoing items are parked for an instant switch back.

    /// Built content below the tabs, by tab (`all` or a host id).
    private var contentCache: [String: [NSMenuItem]] = [:]
    /// The tab whose content is in the menu now.
    private var shownTab = "all"

    private static func cacheKey(_ host: String?) -> String {
        host ?? "all"
    }

    /// Build the other tabs' content in the background of the open menu.
    private func warmTabs() {
        guard let agents = self.store.snapshot?.status.agents, !agents.isEmpty else {
            return
        }
        let hosts: [String?] = [nil] + agents.map(\.host)
        for host in hosts {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.menuOpen else {
                    return
                }
                let key = Self.cacheKey(host)
                guard key != self.shownTab, self.contentCache[key] == nil else {
                    return
                }
                self.contentCache[key] = self.builder(host: host).contentItems()
            }
        }
    }

    /// A tab click (or "Show … only"): the tab bar moves its selection pill in
    /// place, then the content below it is swapped for the cached content of
    /// that tab. The swap waits one run loop turn so the pill animation starts
    /// first, and runs with implicit animations off.
    private func selectHost(_ host: String?) {
        self.selectedHost = host
        if let bar = self.menu.items.first?.view as? AgentTabBar, bar.selected != host {
            bar.select(host, animated: true)
        }
        DispatchQueue.main.async { [weak self] in
            self?.swapContent(to: host)
        }
    }

    private func swapContent(to host: String?) {
        guard MenuBuilder.hasTabs(self.menu) else {
            self.rebuild()
            return
        }
        let key = Self.cacheKey(host)
        guard key != self.shownTab else {
            return
        }
        let incoming = self.contentCache.removeValue(forKey: key) ?? self.builder(host: host).contentItems()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var outgoing: [NSMenuItem] = []
        while self.menu.items.count > MenuBuilder.contentStart {
            outgoing.append(self.menu.items[MenuBuilder.contentStart])
            self.menu.removeItem(at: MenuBuilder.contentStart)
        }
        for (offset, item) in incoming.enumerated() {
            self.menu.insertItem(item, at: MenuBuilder.contentStart + offset)
        }
        CATransaction.commit()
        self.contentCache[self.shownTab] = outgoing
        self.shownTab = key
    }

    /// Forget a tab whose agent moat no longer reports.
    private func validSelection() -> String? {
        guard let host = self.selectedHost else {
            return nil
        }
        if let snapshot = self.store.snapshot, snapshot.agent(host) != nil {
            return host
        }
        return nil
    }
}
