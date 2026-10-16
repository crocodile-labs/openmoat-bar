import Foundation

/// Runs a program and returns what it printed. A seam for tests: the app uses
/// `ProcessRunner`, tests use a stub that returns fixtures.
public protocol CommandRunner {
    func run(_ executable: URL, arguments: [String], timeout: TimeInterval) throws -> Data
}

/// Runs a real process with a deadline, reading stdout and stderr while it runs
/// so a large output cannot fill a pipe and stall it.
public struct ProcessRunner: CommandRunner {
    public var environment: [String: String]?

    public init(environment: [String: String]? = nil) {
        self.environment = environment
    }

    public func run(_ executable: URL, arguments: [String], timeout: TimeInterval) throws -> Data {
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

        guard process.terminationStatus == 0 else {
            let text = String(decoding: err.isEmpty ? out : err, as: UTF8.self)
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
