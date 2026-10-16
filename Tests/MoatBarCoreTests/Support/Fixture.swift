import Foundation
import XCTest
@testable import MoatBarCore

/// Reads a JSON fixture from `Tests/MoatBarCoreTests/Fixtures`.
enum Fixture {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json",
            file: file,
            line: line
        )
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_: T.Type, _ name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: self.data(name))
    }
}

/// Returns canned output per moat subcommand and records what was run.
final class StubRunner: CommandRunner {
    var outputs: [String: Result<Data, MoatError>] = [:]
    private(set) var calls: [[String]] = []

    func run(_: URL, arguments: [String], timeout _: TimeInterval) throws -> Data {
        self.calls.append(arguments)
        guard let result = self.outputs[arguments.first ?? ""] else {
            throw MoatError.failed(command: arguments.first ?? "", message: "no stub")
        }
        return try result.get()
    }
}
