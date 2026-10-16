import Foundation

/// Reads moat. Runs only the read-only commands in `allowedCommands` and
/// decodes their JSON; MoatBar never runs a moat command that changes anything.
public struct MoatClient {
    /// The only moat subcommands MoatBar ever runs.
    public static let allowedCommands: Set<String> = ["status", "show", "report", "proxy", "--version"]

    public var binary: URL
    public var runner: CommandRunner
    public var timeout: TimeInterval

    public init(binary: URL, runner: CommandRunner = ProcessRunner(), timeout: TimeInterval = 3) {
        self.binary = binary
        self.runner = runner
        self.timeout = timeout
    }

    // MARK: - Locating moat

    /// Find moat on `PATH`, then where the installers put it. A menu bar app
    /// launched by macOS gets a short `PATH`, so the usual places are listed.
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
        for dir in dirs where !dir.isEmpty {
            let path = (dir as NSString).appendingPathComponent("moat")
            if isExecutable(path) {
                return URL(fileURLWithPath: path)
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
        try self.decode([Event].self, ["show", "--since", "today", "--format", "json"])
    }

    /// Totals since `window`: `today`, `7d`, `30d`, ...
    public func report(since window: String) throws -> Summary {
        try self.decode(Summary.self, ["report", "--since", window, "--format", "json"])
    }

    public func proxyStatus() throws -> ProxyState {
        try self.decode(ProxyReport.self, ["proxy", "status", "--format", "json"]).state
    }

    /// `moat 0.5.3 (OpenMoat)` → `0.5.3`.
    public func version() throws -> String {
        let text = try String(decoding: self.run(["--version"]), as: UTF8.self)
        let words = text.split(separator: " ")
        guard words.count >= 2 else {
            throw MoatError.unreadable(command: "--version")
        }
        return String(words[1]).trimmingCharacters(in: .whitespacesAndNewlines)
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

    func decode<T: Decodable>(_: T.Type, _ arguments: [String]) throws -> T {
        let data = try self.run(arguments)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MoatError.unreadable(command: arguments.first ?? "")
        }
    }

    func run(_ arguments: [String]) throws -> Data {
        guard let command = arguments.first, Self.allowedCommands.contains(command) else {
            preconditionFailure("MoatBar only runs read-only moat commands")
        }
        return try self.runner.run(self.binary, arguments: arguments, timeout: self.timeout)
    }
}
