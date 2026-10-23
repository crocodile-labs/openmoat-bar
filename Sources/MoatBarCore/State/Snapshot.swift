import Foundation

/// Everything MoatBar knows at one moment, read from moat. Menus and windows
/// are drawn from a snapshot; nothing in it is ever written back.
public struct Snapshot: Equatable {
    public var status: StatusReport
    /// Today's events, oldest first.
    public var events: [Event]
    /// `nil` where moat has no proxy service (Windows) or did not answer.
    public var proxy: ProxyState?
    public var moatVersion: String?
    public var takenAt: Date

    public init(
        status: StatusReport,
        events: [Event],
        proxy: ProxyState? = nil,
        moatVersion: String? = nil,
        takenAt: Date = Date()
    ) {
        self.status = status
        self.events = events
        self.proxy = proxy
        self.moatVersion = moatVersion
        self.takenAt = takenAt
    }

    // MARK: - Agents

    /// Agents that exist on this machine, in moat's order.
    public var installedAgents: [Protection] {
        self.status.agents.filter { $0.level != .notFound }
    }

    /// Agents that were set up but are not protected now.
    public var unprotected: [Protection] {
        self.status.agents.filter { $0.level == .notProtected }
    }

    /// Agents whose calls the hook checks.
    public var protectedCount: Int {
        self.status.agents.filter(\.level.isHooked).count
    }

    public func agent(_ host: String) -> Protection? {
        self.status.agents.first { $0.host == host }
    }

    /// The agent's display name, or for a host `openmoat status` doesn't list
    /// (OpenMoat's proxy, `openmoat run`) its name from `HostText`.
    public func agentName(_ host: String) -> String {
        self.agent(host)?.name ?? HostText.name(forOther: host)
    }

    // MARK: - Events

    /// Events, for one agent (host id) or all of them.
    public func events(for host: String?) -> [Event] {
        guard let host else {
            return self.events
        }
        return self.events.filter { $0.host == host }
    }

    /// Calls per verdict. Every verdict has an entry, zero included.
    public func counts(for host: String? = nil) -> [Verdict: Int] {
        var counts = Dictionary(uniqueKeysWithValues: Verdict.allCases.map { ($0, 0) })
        for event in self.events(for: host) {
            counts[event.verdict, default: 0] += 1
        }
        return counts
    }

    /// Events with one verdict, newest first.
    public func list(_ verdict: Verdict, for host: String? = nil) -> [Event] {
        self.events(for: host).filter { $0.verdict == verdict }.reversed()
    }

    /// Calls per local clock hour (index 0...23) and verdict, for the Today bar.
    public func hourly(for host: String? = nil, calendar: Calendar = .current) -> [[Verdict: Int]] {
        var hours = Array(repeating: [Verdict: Int](), count: 24)
        for event in self.events(for: host) {
            let hour = calendar.component(.hour, from: event.date)
            hours[hour][event.verdict, default: 0] += 1
        }
        return hours
    }

    /// Today's sessions, most recently active first.
    public func sessions(for host: String? = nil) -> [Session] {
        var byId: [String: Session] = [:]
        for event in self.events(for: host) {
            var session = byId[event.sessionId] ?? Session(
                id: event.sessionId,
                host: event.host,
                cwd: event.cwd,
                first: event.date,
                last: event.date,
                counts: [:]
            )
            session.last = max(session.last, event.date)
            session.first = min(session.first, event.date)
            session.counts[event.verdict, default: 0] += 1
            if session.cwd == nil {
                session.cwd = event.cwd
            }
            byId[event.sessionId] = session
        }
        return byId.values.sorted { $0.last != $1.last ? $0.last > $1.last : $0.id < $1.id }
    }

    /// Rules that blocked or asked, most frequent first, ties by name.
    public func topRules(for host: String? = nil) -> [RuleTally] {
        var counts: [String: Int] = [:]
        for event in self.events(for: host) where event.verdict == .deny || event.verdict == .ask {
            if let rule = event.rule {
                counts[rule, default: 0] += 1
            }
        }
        return counts
            .map { RuleTally(rule: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.rule < $1.rule }
    }

    /// When the agent last made a call today.
    public func lastCall(for host: String) -> Date? {
        self.events(for: host).last?.date
    }

    /// The newest blocked call's time, for the "new blocks" dot.
    public var newestBlockMs: Int64? {
        self.events.last { $0.verdict == .deny }?.tsMs
    }
}

/// One rule and how often it blocked or asked.
public struct RuleTally: Equatable {
    public var rule: String
    public var count: Int

    public init(rule: String, count: Int) {
        self.rule = rule
        self.count = count
    }
}

/// One agent session seen today.
public struct Session: Equatable, Identifiable {
    public var id: String
    public var host: String
    public var cwd: String?
    public var first: Date
    public var last: Date
    public var counts: [Verdict: Int]

    public var total: Int {
        self.counts.values.reduce(0, +)
    }
}
