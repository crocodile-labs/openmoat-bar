import Foundation

/// The call an agent made, as moat stores it (already redacted). moat writes it
/// as an externally tagged enum: `{"shell": {"command": "ls"}}`.
/// Shape: openmoat `crates/openmoat-core/src/action.rs`.
public enum Action: Equatable {
    case shell(command: String)
    case foreignShell(shell: String, command: String)
    case fsRead(path: String)
    case fsWrite(path: String)
    case net(url: String)
    case fetch(url: String)
    case webSearch(query: String)
    case unknownTool(host: String, tool: String)
    case patch(writes: [String])
    case readFiles(paths: [String])
    case mcpTool(name: String)
    /// A kind a newer moat added.
    case other(kind: String)

    /// One line a person can read: the command, or the tool and what it touched.
    public var display: String {
        switch self {
        case let .shell(command): return command
        case let .foreignShell(shell, command): return "\(shell): \(command)"
        case let .fsRead(path): return "Read \(path)"
        case let .fsWrite(path): return "Write \(path)"
        case let .net(url): return "Connect to \(url)"
        case let .fetch(url): return "Fetch \(url)"
        case let .webSearch(query): return "Search \u{201C}\(query)\u{201D}"
        case let .unknownTool(_, tool): return tool
        case let .patch(writes):
            return writes.count == 1 ? "Patch \(writes[0])" : "Patch \(writes.count) files"
        case let .readFiles(paths):
            return paths.count == 1 ? "Read \(paths[0])" : "Read \(paths.count) files"
        case let .mcpTool(name): return name
        case let .other(kind): return kind
        }
    }

    /// The command line, for actions `moat policy check` can check again.
    public var shellCommand: String? {
        if case let .shell(command) = self {
            return command
        }
        return nil
    }
}

// MARK: - Action + Codable

extension Action: Codable {
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue _: Int) {
            nil
        }
    }

    private struct Fields: Codable {
        var command: String?
        var shell: String?
        var path: String?
        var url: String?
        var query: String?
        var host: String?
        var tool: String?
        var writes: [String]?
        var paths: [String]?
        var name: String?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "empty action")
            )
        }
        let f = (try? container.decode(Fields.self, forKey: key)) ?? Fields()
        switch key.stringValue {
        case "shell": self = .shell(command: f.command ?? "")
        case "foreign_shell": self = .foreignShell(shell: f.shell ?? "shell", command: f.command ?? "")
        case "fs_read": self = .fsRead(path: f.path ?? "")
        case "fs_write": self = .fsWrite(path: f.path ?? "")
        case "net": self = .net(url: f.url ?? "")
        case "fetch": self = .fetch(url: f.url ?? "")
        case "web_search": self = .webSearch(query: f.query ?? "")
        case "unknown_tool": self = .unknownTool(host: f.host ?? "", tool: f.tool ?? "")
        case "patch": self = .patch(writes: f.writes ?? [])
        case "read_files": self = .readFiles(paths: f.paths ?? [])
        case "mcp_tool": self = .mcpTool(name: f.name ?? "")
        default: self = .other(kind: key.stringValue)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        var f = Fields()
        let key: String
        switch self {
        case let .shell(command): key = "shell"; f.command = command
        case let .foreignShell(shell, command): key = "foreign_shell"; f.shell = shell; f.command = command
        case let .fsRead(path): key = "fs_read"; f.path = path
        case let .fsWrite(path): key = "fs_write"; f.path = path
        case let .net(url): key = "net"; f.url = url
        case let .fetch(url): key = "fetch"; f.url = url
        case let .webSearch(query): key = "web_search"; f.query = query
        case let .unknownTool(host, tool): key = "unknown_tool"; f.host = host; f.tool = tool
        case let .patch(writes): key = "patch"; f.writes = writes
        case let .readFiles(paths): key = "read_files"; f.paths = paths
        case let .mcpTool(name): key = "mcp_tool"; f.name = name
        case let .other(kind): key = kind
        }
        try container.encode(f, forKey: Key(stringValue: key))
    }
}
