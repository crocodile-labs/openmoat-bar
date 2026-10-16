import Foundation

/// moat's own state directory: `$MOAT_HOME`, else `~/.moat`. MoatBar only
/// watches it for changes; it never writes there.
public enum MoatHome {
    public static func directory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let custom = environment["MOAT_HOME"], !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        let home = environment["HOME"] ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(".moat", isDirectory: true)
    }

    /// The audit database moat appends every decision to (SQLite; writes land
    /// in `audit.db-wal` first).
    public static func auditFiles(in directory: URL) -> [URL] {
        ["audit.db", "audit.db-wal"].map { directory.appendingPathComponent($0) }
    }
}
