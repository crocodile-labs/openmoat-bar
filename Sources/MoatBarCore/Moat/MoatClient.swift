import Foundation

/// Reads moat. Runs only the read-only command lines in `allowedCommands` and
/// decodes their JSON; MoatBar never runs a moat command that changes anything.
public struct MoatClient {
    /// The only moat command lines MoatBar ever runs, word for word; `*` is
    /// one `--since` value. Whole lines, not just the first word: `doctor`
    /// re-pins with `--accept`, `secret add` edits the policy, and `proxy`
    /// alone runs the proxy.
    public static let allowedCommands: [[String]] = [
        ["status", "--format", "json"],
        ["show", "--since", "*", "--format", "json"],
        ["report", "--since", "*", "--format", "json"],
        ["proxy", "status", "--format", "json"],
        ["--version"],
        ["allowed", "--format", "json"],
        ["secret", "list", "--format", "json"],
        ["doctor", "--format", "json"],
    ]

    /// Whether `arguments` is one of `allowedCommands`.
    public static func isAllowed(_ arguments: [String]) -> Bool {
        self.allowedCommands.contains { line in
            line.count == arguments.count && zip(line, arguments).allSatisfy { $0 == "*" || $0 == $1 }
        }
    }

    public var binary: URL
    public var runner: CommandRunner
    public var timeout: TimeInterval

    public init(binary: URL, runner: CommandRunner = ProcessRunner(), timeout: TimeInterval = 3) {
        self.binary = binary
        self.runner = runner
        self.timeout = timeout
    }

    // MARK: - Locating openmoat

    /// Find openmoat on `PATH`, then where the installers put it. A menu bar app
    /// launched by macOS gets a short `PATH`, so the usual places are listed.
    /// An install from before the rename has only `moat`; that is looked for
    /// everywhere after `openmoat`, since the old name goes away in a later release.
    public static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) -> URL? {
        let home = environment["HOME"] ?? NSHomeDirectory()
        var dirs = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        dirs += [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(home)/.cargo/bin",
            "/home/linuxbrew/.linuxbrew/bin",
            "\(home)/.local/bin",
        ]
        for name in ["openmoat", "moat"] {
            for dir in dirs where !dir.isEmpty {
                let path = (dir as NSString).appendingPathComponent(name)
                if isExecutable(path) {
                    return URL(fileURLWithPath: path)
                }
            }
        }
        return nil
    }

    // MARK: - Commands

    public func status() throws -> StatusReport {
        try self.decode(StatusReport.self, ["status", "--format", "json"])
    }

    /// Today's events (local midnight as moat counts it), oldest first.
    public func eventsToday() throws -> [Event] {
        try self.events(since: .today)
    }

    /// Events in a window, oldest first.
    public func events(since window: TimeWindow) throws -> [Event] {
        try self.decode([Event].self, ["show", "--since", window.rawValue, "--format", "json"])
    }

    /// Totals since `window`: `today`, `7d`, `30d`, ...
    public func report(since window: String) throws -> Summary {
        try self.decode(Summary.self, ["report", "--since", window, "--format", "json"])
    }

    public func proxyStatus() throws -> ProxyState {
        try self.decode(ProxyReport.self, ["proxy", "status", "--format", "json"]).state
    }

    /// `openmoat 0.9.0 (OpenMoat)` → `0.9.0`; before the rename, `moat 0.5.3 (OpenMoat)`.
    public func version() throws -> String {
        let text = try String(bytes: self.run(["--version"]), encoding: .utf8) ?? ""
        let words = text.split(separator: " ")
        guard words.count >= 2 else {
            throw MoatError.unreadable(command: "--version")
        }
        return String(words[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What the person allowed (OpenMoat 0.5.5 and later).
    public func allowed() throws -> AllowedReport {
        try self.decode(AllowedReport.self, ["allowed", "--format", "json"])
    }

    /// Brokered secrets, never their values (OpenMoat 0.5.5 and later).
    public func secrets() throws -> SecretList {
        try self.decode(SecretList.self, ["secret", "list", "--format", "json"])
    }

    /// Every `openmoat doctor` check (OpenMoat 0.5.5 and later). moat exits 64
    /// after printing them when one is a problem.
    public func doctor() throws -> DoctorReport {
        try self.decode(DoctorReport.self, ["doctor", "--format", "json"], okExitCodes: [0, 64])
    }

    /// The three detail screens. A moat older than 0.5.5 gets a note per
    /// screen instead of an error, without running the commands it lacks.
    public func details(now: Date = Date()) -> Details {
        let version = try? self.version()
        let minimum = MoatRequirement.screens
        return Details(
            allowed: .read(minimum: minimum, version: version) { try self.allowed() },
            secrets: .read(minimum: minimum, version: version) { try self.secrets() },
            checks: .read(minimum: minimum, version: version) { try self.doctor() },
            takenAt: now
        )
    }

    /// Everything the menu needs. Status and events are required; the proxy
    /// state and version are shown when moat gives them.
    public func snapshot(now: Date = Date()) throws -> Snapshot {
        let status = try self.status()
        let events = try self.eventsToday()
        return Snapshot(
            status: status,
            events: events,
            proxy: try? self.proxyStatus(),
            moatVersion: try? self.version(),
            takenAt: now
        )
    }

    // MARK: - Running

    func decode<T: Decodable>(_: T.Type, _ arguments: [String], okExitCodes: Set<Int32> = [0]) throws -> T {
        let data = try self.run(arguments, okExitCodes: okExitCodes)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MoatError.unreadable(command: arguments.first ?? "")
        }
    }

    func run(_ arguments: [String], okExitCodes: Set<Int32> = [0]) throws -> Data {
        guard Self.isAllowed(arguments) else {
            preconditionFailure("MoatBar only runs read-only openmoat commands")
        }
        if okExitCodes == [0] {
            return try self.runner.run(self.binary, arguments: arguments, timeout: self.timeout)
        }
        return try self.runner.run(self.binary, arguments: arguments, timeout: self.timeout, okExitCodes: okExitCodes)
    }
}
