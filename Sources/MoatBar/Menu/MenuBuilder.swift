import AppKit
import MoatBarCore
import SwiftUI

/// Builds the whole menu from one snapshot. Rows with › open a submenu beside
/// them; nothing in the menu changes OpenMoat.
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

    func fill(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let snapshot = self.snapshot else {
            self.addUnavailable(to: menu)
            self.addFooter(to: menu)
            return
        }
        let agents = snapshot.installedAgents
        if !agents.isEmpty {
            let tabs = AgentTabs(agents: agents, selected: self.selectedHost, onSelect: self.onSelectHost)
            menu.addItem(hostedItem(tabs))
            menu.addItem(.separator())
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

    // MARK: - Security checks

    private func addChecks(_ snapshot: Snapshot, to menu: NSMenu) {
        let checks = SecurityChecks.from(snapshot)
        let attention = SecurityChecks.needingAttention(checks).count
        let item = NSMenuItem()
        item.attributedTitle = Format.checksRow(attention: attention)
        let sub = NSMenu()
        sub.autoenablesItems = false
        let header = NSMenuItem(title: "Security checks", action: nil, keyEquivalent: "")
        header.isEnabled = false
        sub.addItem(header)
        sub.addItem(.separator())
        for check in checks {
            if let fix = check.fix {
                let row = ClosureMenuItem("") { Actions.copy(fix) }
                row.attributedTitle = Format.checkRow(check, copyHint: true)
                row.toolTip = "Copies \(fix)"
                sub.addItem(row)
            } else {
                let row = NSMenuItem()
                row.attributedTitle = Format.checkRow(check, copyHint: false)
                row.isEnabled = false
                sub.addItem(row)
            }
        }
        sub.addItem(.separator())
        sub.addItem(ClosureMenuItem("Copy \(CopyCommands.doctor) for every check") {
            Actions.copy(CopyCommands.doctor)
        })
        item.submenu = sub
        menu.addItem(.separator())
        menu.addItem(item)
    }

    // MARK: - Header and problems

    private func addHeader(_ snapshot: Snapshot, to menu: NSMenu) {
        let title: String
        let detail: String
        if let host = self.selectedHost, let agent = snapshot.agent(host) {
            title = agent.name
            detail = agent.level.label
        } else {
            title = "All agents"
            let setUp = snapshot.installedAgents.filter { $0.level != .notSetUp }.count
            detail = "\(snapshot.protectedCount) of \(max(setUp, snapshot.protectedCount)) protected"
        }
        let updated: String
        if let error = self.error {
            updated = "Last good data \(Format.clock(snapshot.takenAt)) · \(error.message)"
        } else {
            updated = "Updated \(Format.relative(snapshot.takenAt, now: self.now))"
        }
        let version = snapshot.moatVersion.map { "moat \($0)" } ?? ""
        menu.addItem(hostedItem(HeaderView(title: title, trailing: version, updated: updated, detail: detail)))
    }

    private func addProblems(_ snapshot: Snapshot, to menu: NSMenu) {
        for agent in snapshot.unprotected where self.selectedHost == nil || self.selectedHost == agent.host {
            let why = agent.reason.map { "OpenMoat says: \($0). " } ?? ""
            menu.addItem(hostedItem(ProblemCard(
                title: "\(agent.name) is not protected",
                text: "\(why)Its calls are not being checked.",
                command: CopyCommands.setUp,
                note: "Run it in Terminal. It shows the change and asks first. This goes away on the next check."
            )))
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

    // MARK: - Verdicts

    private func addVerdicts(_ snapshot: Snapshot, to menu: NSMenu) {
        let counts = snapshot.counts(for: self.selectedHost)
        for verdict in [Verdict.deny, .ask, .deferred, .allow] {
            let count = counts[verdict] ?? 0
            let item = NSMenuItem()
            item.attributedTitle = Format.verdictRow(verdict, count: count)
            item.image = Format.dot(verdict.nsColor)
            let events = snapshot.list(verdict, for: self.selectedHost)
            item.submenu = self.list(verdict, events: events, snapshot: snapshot)
            menu.addItem(item)
        }
    }

    private func list(_ verdict: Verdict, events: [Event], snapshot: Snapshot) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let header = NSMenuItem(title: "\(verdict.title) today · \(events.count)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        if events.isEmpty {
            let empty = NSMenuItem(title: "Nothing \(verdict.title.lowercased()) today", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return menu
        }
        for event in events.prefix(Self.listLimit) {
            let item = NSMenuItem()
            item.attributedTitle = Format.eventRow(event, agent: self.agentName(event.host, snapshot))
            item.submenu = self.decision(event, snapshot: snapshot)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let more = events.count > Self.listLimit ? " (\(events.count - Self.listLimit) more)" : ""
        menu.addItem(ClosureMenuItem("Show all in Activity…\(more)") { self.onActivity(verdict) })
        return menu
    }

    private func decision(_ event: Event, snapshot: Snapshot) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(hostedItem(DecisionView(
            event: event,
            agentName: self.agentName(event.host, snapshot),
            time: Format.clock(event.date)
        )))
        menu.addItem(.separator())
        if let action = event.action, let check = CopyCommands.policyCheck(action) {
            menu.addItem(ClosureMenuItem("Copy check command") { Actions.copy(check) })
        }
        if event.verdict == .deny || event.verdict == .ask {
            menu.addItem(ClosureMenuItem("Why was this blocked? ↗") { Actions.open(DocsLink.blocked) })
            menu.addItem(ClosureMenuItem("Report a wrong block ↗") {
                Actions.open(DocsLink.reportWrongBlock(rule: event.rule))
            })
        } else {
            menu.addItem(ClosureMenuItem("How OpenMoat decides ↗") { Actions.open(DocsLink.checkACommand) })
        }
        return menu
    }

    // MARK: - Agents

    private func addAgents(_ snapshot: Snapshot, to menu: NSMenu) {
        let header = NSMenuItem(title: "Agents", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for agent in snapshot.installedAgents {
            let counts = snapshot.counts(for: agent.host)
            let item = NSMenuItem()
            item.attributedTitle = Format.agentRow(
                agent,
                counts: counts,
                lastCall: snapshot.lastCall(for: agent.host).map { Format.relative($0, now: self.now) }
            )
            item.image = Format.dot(agent.level.nsColor)
            item.submenu = self.agentMenu(agent, snapshot: snapshot)
            menu.addItem(item)
        }
        if let proxy = snapshot.proxy {
            let item = NSMenuItem(title: "Network proxy: \(proxy.label)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func agentMenu(_ agent: Protection, snapshot: Snapshot) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(hostedItem(AgentDetailView(
            agent: agent,
            lastCall: snapshot.lastCall(for: agent.host).map { Format.relative($0, now: self.now) }
        )))
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Show \(agent.name) only") { self.onSelectHost(agent.host) })
        if agent.level == .notSetUp || agent.level == .notProtected {
            menu.addItem(ClosureMenuItem("Copy set-up command (moat)") { Actions.copy(CopyCommands.setUp) })
        }
        menu.addItem(ClosureMenuItem("Known limits ↗") { Actions.open(DocsLink.limits) })
        return menu
    }

    private func addAgentDetail(_ agent: Protection, snapshot: Snapshot, to menu: NSMenu) {
        menu.addItem(hostedItem(AgentDetailView(
            agent: agent,
            lastCall: snapshot.lastCall(for: agent.host).map { Format.relative($0, now: self.now) }
        )))
        let sessions = snapshot.sessions(for: agent.host)
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(string: "Sessions today · \(sessions.count)")
        let sub = NSMenu()
        sub.autoenablesItems = false
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
        item.submenu = sub
        menu.addItem(item)
    }

    // MARK: - Unavailable and footer

    private func addUnavailable(to menu: NSMenu) {
        if self.error == nil || self.error == .notInstalled {
            menu.addItem(hostedItem(ProblemCard(
                title: "OpenMoat isn't installed",
                text: "MoatBar shows what OpenMoat does. Without it, your agents run with only their own prompts.",
                command: CopyCommands.install,
                note: "MoatBar looks for moat again every minute.",
                tint: Color(nsColor: .secondaryLabelColor)
            )))
            menu.addItem(ClosureMenuItem("Install guide ↗") { Actions.open(DocsLink.quickstart) })
        } else if let error = self.error {
            menu.addItem(hostedItem(ProblemCard(
                title: "Couldn't read OpenMoat",
                text: "\(error.message). Your agents are still checked; only this view is out of date.",
                command: CopyCommands.doctor,
                note: "moat doctor shows what is wrong.",
                tint: Color(nsColor: .systemOrange)
            )))
        }
    }

    private func addFooter(to menu: NSMenu) {
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Activity window…", key: "a") { self.onActivity(.deny) })
        menu.addItem(ClosureMenuItem("Refresh", key: "r") { self.onRefresh() })
        menu.addItem(ClosureMenuItem("OpenMoat docs ↗") { Actions.open(DocsLink.home) })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Settings…", key: ",") { self.onSettings() })
        menu.addItem(ClosureMenuItem("About MoatBar") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(ClosureMenuItem("Quit MoatBar", key: "q") { NSApp.terminate(nil) })
    }

    private func agentName(_ host: String, _ snapshot: Snapshot) -> String {
        snapshot.agent(host)?.name ?? host
    }
}
