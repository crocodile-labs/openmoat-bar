import Foundation

/// Runs a program and returns what it printed. A seam for tests: the app uses
/// `ProcessRunner`, tests use a stub that returns fixtures.
public protocol CommandRunner {
    func run(_ executable: URL, arguments: [String], timeout: TimeInterval) throws -> Data
    /// The same, but an exit code in `okExitCodes` that printed something is
    /// not a failure: `moat doctor` exits non-zero after printing its checks
    /// when one found a problem.
    func run(_ executable: URL, arguments: [String], timeout: TimeInterval, okExitCodes: Set<Int32>) throws -> Data
}

public extension CommandRunner {
    /// Runners that return canned output (tests) have no exit codes to judge.
    func run(
        _ executable: URL,
        arguments: [String],
        timeout: TimeInterval,
        okExitCodes _: Set<Int32>
    ) throws -> Data {
        try self.run(executable, arguments: arguments, timeout: timeout)
    }
}

/// Runs a real process with a deadline, reading stdout and stderr while it runs
/// so a large output cannot fill a pipe and stall it.
public struct ProcessRunner: CommandRunner {
    public var environment: [String: String]?

    public init(environment: [String: String]? = nil) {
        self.environment = environment
    }

    public func run(_ executable: URL, arguments: [String], timeout: TimeInterval) throws -> Data {
        try self.run(executable, arguments: arguments, timeout: timeout, okExitCodes: [0])
    }

    public func run(
        _ executable: URL,
        arguments: [String],
        timeout: TimeInterval,
        okExitCodes: Set<Int32>
    ) throws -> Data {
        let command = arguments.first ?? ""
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let environment = self.environment {
            process.environment = environment
        }
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do {
            try process.run()
        } catch {
            throw MoatError.notInstalled
        }

        let output = PipeCollector(stdout: stdout, stderr: stderr)
        if exited.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            _ = exited.wait(timeout: .now() + 1)
            throw MoatError.timedOut(command: arguments.joined(separator: " "))
        }
        let (out, err) = output.finish()

        let status = process.terminationStatus
        let accepted = status == 0 || (okExitCodes.contains(status) && !out.isEmpty)
        guard accepted, process.terminationReason == .exit else {
            let text = String(bytes: err.isEmpty ? out : err, encoding: .utf8) ?? ""
            let first = text.split(separator: "\n").first.map(String.init)
                ?? "exit \(process.terminationStatus)"
            let message = first.hasPrefix("moat: ") ? String(first.dropFirst(6)) : first
            throw MoatError.failed(command: command, message: message)
        }
        return out
    }
}

/// Drains both pipes on background queues.
private final class PipeCollector {
    private let group = DispatchGroup()
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()

    init(stdout: Pipe, stderr: Pipe) {
        self.drain(stdout) { self.out = $0 }
        self.drain(stderr) { self.err = $0 }
    }

    private func drain(_ pipe: Pipe, into store: @escaping (Data) -> Void) {
        self.group.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            self.lock.lock()
            store(data)
            self.lock.unlock()
            self.group.leave()
        }
    }

    func finish() -> (Data, Data) {
        self.group.wait()
        self.lock.lock()
        defer { self.lock.unlock() }
        return (self.out, self.err)
    }
}
