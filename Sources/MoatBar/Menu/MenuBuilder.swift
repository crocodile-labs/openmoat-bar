import AppKit
import MoatBarCore
import SwiftUI

/// Builds the menu from one snapshot. Rows with › open a submenu beside them;
/// submenus are built the first time they open. Nothing in the menu changes
/// OpenMoat.
struct MenuBuilder {
    let snapshot: Snapshot?
    let error: MoatError?
    let selectedHost: String?
    let onSelectHost: (String?) -> Void
    let onRefresh: () -> Void
    let onSettings: () -> Void
    let onActivity: (Verdict?) -> Void
    var now = Date()

    /// Longest list a verdict submenu shows; the rest is in the Activity window.
    static let listLimit = 40
    /// Width of list and decision submenus.
    static let submenuWidth: CGFloat = 380
    /// Marks the tab row, which stays in place when the content changes.
    private static let tabsTag = "agent-tabs"

    /// Build the whole menu: tabs, then everything below them.
    func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        // Every agent OpenMoat supports gets a tab, installed or not, so the
        // row reads the same on every Mac.
        if let agents = self.snapshot?.status.agents, !agents.isEmpty {
            let item = NSMenuItem()
            item.view = AgentTabBar(
                width: menuWidth,
                tabs: Self.tabs(for: agents),
                selected: self.selectedHost,
                onSelect: self.onSelectHost
            )
            item.representedObject = Self.tabsTag
            menu.addItem(item)
            menu.addItem(.separator())
        }
        self.appendContent(to: menu)
    }

    /// All, then every agent. The line under "All" is red when any agent lost
    /// protection; an agent that isn't installed is drawn faded.
    static func tabs(for agents: [Protection]) -> [AgentTabBar.Tab] {
        let anyBroken = agents.contains { $0.level == .notProtected }
        let all = AgentTabBar.Tab(
            host: nil,
            title: "All",
            lineColor: anyBroken ? Level.notProtected.nsColor : Level.hookAndOsSandbox.nsColor,
            faded: false
        )
        return [all] + agents.map { agent in
            AgentTabBar.Tab(
                host: agent.host,
                title: agent.name == "Claude Code" ? "Claude" : agent.name,
                lineColor: agent.level.nsColor,
                faded: agent.level == .notFound
            )
        }
    }

    /// Whether `menu` starts with the tab bar and its separator.
    static func hasTabs(_ menu: NSMenu) -> Bool {
        menu.items.first?.representedObject as? String == self.tabsTag && menu.items.count >= 2
    }

    /// Index of the first item below the tab bar.
    static let contentStart = 2

    /// Everything below the tabs, built into detached items so they can be
    /// cached and swapped in when a tab is clicked.
    func contentItems() -> [NSMenuItem] {
        let scratch = NSMenu()
        scratch.autoenablesItems = false
        self.appendContent(to: scratch)
        let items = scratch.items
        scratch.removeAllItems()
        return items
    }

    private func appendContent(to menu: NSMenu) {
        guard let snapshot = self.snapshot else {
            self.addUnavailable(to: menu)
            self.addFooter(to: menu)
            return
        }
        self.addHeader(snapshot, to: menu)
        self.addProblems(snapshot, to: menu)
        self.addToday(snapshot, to: menu)
        menu.addItem(.separator())
        self.addVerdicts(snapshot, to: menu)
        menu.addItem(.separator())
        if let host = self.selectedHost, let agent = snapshot.agent(host) {
            self.addAgentDetail(agent, snapshot: snapshot, to: menu)
        } else {
            self.addAgents(snapshot, to: menu)
        }
        self.addChecks(snapshot, to: menu)
        self.addFooter(to: menu)
    }

    // MARK: - Header and problems

    private func addHeader(_ snapshot: Snapshot, to menu: NSMenu) {
        let title: String
        let detail: String
        let color: Color
        if let host = self.selectedHost, let agent = snapshot.agent(host) {
            title = agent.name
            detail = agent.level.label
            color = agent.level.color
        } else {
            title = "All agents"
            let setUp = snapshot.installedAgents.filter { $0.level != .notSetUp }.count
            detail = "\(snapshot.protectedCount) of \(max(setUp, snapshot.protectedCount)) protected"
            color = snapshot.unprotected.isEmpty ? Level.hookAndOsSandbox.color : Level.notProtected.color
        }
        let updated: String
        if let error = self.error {
            updated = "Last good data \(Format.clock(snapshot.takenAt)) · \(error.message)"
        } else {
            updated = "Updated \(Format.relative(snapshot.takenAt, now: self.now))"
        }
        let version = snapshot.moatVersion.map { "moat \($0)" } ?? ""
        menu.addItem(hostedItem(HeaderView(
            title: title,
            trailing: version,
            updated: updated,
            detail: detail,
            detailColor: color
        )))
    }

    private func addProblems(_ snapshot: Snapshot, to menu: NSMenu) {
        for agent in snapshot.unprotected where self.selectedHost == nil || self.selectedHost == agent.host {
            let why = agent.reason.map { "OpenMoat says: \($0). " } ?? ""
            menu.addItem(hostedItem(ProblemCard(
                title: "\(agent.name) is not protected",
                text: "\(why)Its calls are not being checked.",
                note: "Run moat in Terminal. It shows the change and asks first. This goes away on the next check."
            )))
            menu.addItem(copyItem("Copy the fix", command: CopyCommands.setUp))
        }
    }

    private func addToday(_ snapshot: Snapshot, to menu: NSMenu) {
        let host = self.selectedHost
        let hour = Calendar.current.component(.hour, from: self.now)
        menu.addItem(hostedItem(TodayBar(
            hours: snapshot.hourly(for: host),
            total: snapshot.events(for: host).count,
            sessions: snapshot.sessions(for: host).count,
            currentHour: hour
        )))
    }

    // MARK: - Verdicts, lists and decisions

    private func addVerdicts(_ snapshot: Snapshot, to menu: NSMenu) {
        let counts = snapshot.counts(for: self.selectedHost)
        for verdict in [Verdict.deny, .ask, .deferred, .allow] {
            let events = snapshot.list(verdict, for: self.selectedHost)
            let submenu = LazyMenu(width: Self.submenuWidth) { sub in
                self.fillList(sub, verdict: verdict, events: events, snapshot: snapshot)
            }
            menu.addItem(rowItem(submenu: submenu) { state in
                AnyView(VerdictRow(state: state, verdict: verdict, count: counts[verdict] ?? 0))
            })
        }
    }

    private func fillList(_ menu: NSMenu, verdict: Verdict, events: [Event], snapshot: Snapshot) {
        let header = SectionHeader(title: "\(verdict.title) today", trailing: Format.count(events.count))
        menu.addItem(hostedItem(header, width: Self.submenuWidth))
        if events.isEmpty {
            let empty = NSMenuItem(title: "Nothing \(verdict.title.lowercased()) today", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for event in events.prefix(Self.listLimit) {
            let agent = self.agentName(event.host, snapshot)
            let decision = LazyMenu(width: Self.submenuWidth) { sub in
                self.fillDecision(sub, event: event, agent: agent)
            }
            menu.addItem(rowItem(width: Self.submenuWidth, submenu: decision) { state in
                AnyView(EventRow(state: state, event: event, agentName: agent))
            })
        }
        menu.addItem(.separator())
        let more = events.count > Self.listLimit ? " (\(events.count - Self.listLimit) more)" : ""
        menu.addItem(ClosureMenuItem("Show all in Activity…\(more)") { self.onActivity(verdict) })
    }

    private func fillDecision(_ menu: NSMenu, event: Event, agent: String) {
        menu.addItem(hostedItem(
            DecisionView(event: event, agentName: agent, time: Format.clock(event.date)),
            width: Self.submenuWidth
        ))
        menu.addItem(.separator())
        if let action = event.action, let check = CopyCommands.policyCheck(action) {
            menu.addItem(copyItem("Copy check command", command: check, width: Self.submenuWidth))
        }
        if event.verdict == .deny || event.verdict == .ask {
            menu.addItem(ClosureMenuItem("Why was this blocked? ↗") { Actions.open(DocsLink.blocked) })
            menu.addItem(ClosureMenuItem("Report a wrong block ↗") {
                Actions.open(DocsLink.reportWrongBlock(rule: event.rule))
            })
        } else {
            menu.addItem(ClosureMenuItem("How OpenMoat decides ↗") { Actions.open(DocsLink.checkACommand) })
        }
        menu.addItem(ClosureMenuItem("Show in Activity…") { self.onActivity(event.verdict) })
    }

    // MARK: - Agents

    private func addAgents(_ snapshot: Snapshot, to menu: NSMenu) {
        menu.addItem(hostedItem(SectionHeader(title: "Agents")))
        for agent in snapshot.installedAgents {
            let counts = snapshot.counts(for: agent.host)
            let lastCall = snapshot.lastCall(for: agent.host).map { Format.relative($0, now: self.now) }
            let submenu = LazyMenu { sub in
                self.fillAgent(sub, agent: agent, lastCall: lastCall)
            }
            menu.addItem(rowItem(submenu: submenu) { state in
                AnyView(AgentRow(state: state, agent: agent, counts: counts, lastCall: lastCall))
            })
        }
        if let proxy = snapshot.proxy {
            let item = NSMenuItem(title: "Network proxy: \(proxy.label)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func fillAgent(_ menu: NSMenu, agent: Protection, lastCall: String?) {
        menu.addItem(hostedItem(AgentDetailView(agent: agent, lastCall: lastCall)))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Show \(agent.name) only") { self.onSelectHost(agent.host) })
        if agent.level == .notSetUp || agent.level == .notProtected {
            menu.addItem(copyItem("Copy the set-up command", command: CopyCommands.setUp))
        }
        menu.addItem(ClosureMenuItem("Known limits ↗") { Actions.open(DocsLink.limits) })
    }

    private func addAgentDetail(_ agent: Protection, snapshot: Snapshot, to menu: NSMenu) {
        let lastCall = snapshot.lastCall(for: agent.host).map { Format.relative($0, now: self.now) }
        menu.addItem(hostedItem(AgentDetailView(agent: agent, lastCall: lastCall)))
        let sessions = snapshot.sessions(for: agent.host)
        let sub = LazyMenu { sub in
            if sessions.isEmpty {
                let empty = NSMenuItem(title: "\(agent.name) hasn't run today", action: nil, keyEquivalent: "")
                empty.isEnabled = false
                sub.addItem(empty)
            }
            for session in sessions {
                let row = NSMenuItem()
                row.attributedTitle = Format.sessionRow(session, now: self.now)
                row.isEnabled = false
                sub.addItem(row)
            }
        }
        menu.addItem(rowItem(submenu: sub) { state in
            AnyView(ActionRow(state: state, title: "Sessions today", symbol: "clock", hint: "\(sessions.count)"))
        })
    }

    // MARK: - Security checks

    private func addChecks(_ snapshot: Snapshot, to menu: NSMenu) {
        let checks = SecurityChecks.from(snapshot)
        let attention = SecurityChecks.needingAttention(checks).count
        let sub = LazyMenu(width: Self.submenuWidth) { sub in
            sub.addItem(hostedItem(SectionHeader(title: "Security checks"), width: Self.submenuWidth))
            for check in checks {
                let row = NSMenuItem()
                row.attributedTitle = Format.checkRow(check)
                row.isEnabled = false
                sub.addItem(row)
                if let fix = check.fix, check.kind >= .info {
                    sub.addItem(copyItem("Copy the fix", command: fix, width: Self.submenuWidth))
                }
            }
            sub.addItem(.separator())
            sub.addItem(copyItem("Copy for every check", command: CopyCommands.doctor, width: Self.submenuWidth))
        }
        menu.addItem(.separator())
        let hint = attention > 0 ? "\(attention) to look at" : "all fine"
        menu.addItem(rowItem(submenu: sub) { state in
            AnyView(ActionRow(state: state, title: "Security checks", symbol: "checkmark.shield", hint: hint))
        })
    }

    // MARK: - Unavailable and footer

    private func addUnavailable(to menu: NSMenu) {
        if self.error == nil || self.error == .notInstalled {
            menu.addItem(hostedItem(ProblemCard(
                title: "OpenMoat isn't installed",
                text: "MoatBar shows what OpenMoat does. Without it, your agents run with only their own prompts.",
                note: "MoatBar looks for moat again every minute.",
                tint: Color(nsColor: .secondaryLabelColor)
            )))
            menu.addItem(copyItem("Copy the install command", command: CopyCommands.install))
            menu.addItem(ClosureMenuItem("Install guide ↗") { Actions.open(DocsLink.quickstart) })
        } else if let error = self.error {
            menu.addItem(hostedItem(ProblemCard(
                title: "Couldn't read OpenMoat",
                text: "\(error.message). Your agents are still checked; only this view is out of date.",
                note: "moat doctor shows what is wrong.",
                tint: Color(nsColor: .systemOrange)
            )))
            menu.addItem(copyItem("Copy the check command", command: CopyCommands.doctor))
        }
    }

    private func addFooter(to menu: NSMenu) {
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Activity window…", key: "a") { self.onActivity(.deny) })
        menu.addItem(ClosureMenuItem("Refresh", key: "r") { self.onRefresh() })
        menu.addItem(ClosureMenuItem("OpenMoat docs ↗") { Actions.open(DocsLink.home) })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Settings…", key: ",") { self.onSettings() })
        menu.addItem(ClosureMenuItem("About MoatBar") { Actions.showAbout() })
        menu.addItem(ClosureMenuItem("Quit MoatBar", key: "q") { NSApp.terminate(nil) })
    }

    private func agentName(_ host: String, _ snapshot: Snapshot) -> String {
        snapshot.agent(host)?.name ?? host
    }
}
