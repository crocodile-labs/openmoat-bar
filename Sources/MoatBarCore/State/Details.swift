import Foundation

/// The OpenMoat versions OpenMoat Bar's newer screens need, and the note shown on
/// an older one instead of an error.
public enum MoatRequirement {
    /// `openmoat allowed`, `openmoat secret list` and `openmoat doctor` with `--format json`.
    public static let screens = "0.5.5"
    /// `policy_update` and `lock_drift` in `openmoat status --format json`.
    public static let updateNotices = "0.5.7"

    /// What a screen says when moat is older than `minimum`.
    public static func note(_ minimum: String) -> String {
        "This needs OpenMoat \(minimum) or later. Update OpenMoat to see it here."
    }

    /// The note for a status without update notices; `nil` when moat sends them.
    public static func updateNoticesNote(for status: StatusReport) -> String? {
        status.hasUpdateNotices
            ? nil
            : "Policy update and changed-file notices need OpenMoat \(self.updateNotices) or later."
    }
}

public enum MoatVersion {
    /// Whether `version` (`0.5.6`, `0.5.7-rc.1`) is at least `minimum`;
    /// `nil` when it can't be read. A pre-release counts as its version.
    public static func isAtLeast(_ version: String?, _ minimum: String) -> Bool? {
        guard let version, let have = self.parts(version), let need = self.parts(minimum) else {
            return nil
        }
        for (a, b) in zip(have, need) where a != b {
            return a > b
        }
        return true
    }

    private static func parts(_ text: String) -> [Int]? {
        let core = text.trimmingCharacters(in: .whitespaces).split(separator: "-").first.map(String.init) ?? ""
        let numbers = core.split(separator: ".").map { Int($0) }
        guard numbers.count == 3, numbers.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return numbers.compactMap { $0 }
    }
}

/// What one screen shows: moat's answer, a note that this moat is too old for
/// it, or why moat could not be read.
public enum ScreenState<Value: Equatable>: Equatable {
    case loaded(Value)
    case needsNewerMoat(note: String)
    case failed(message: String)

    /// Run `body` unless `version` is known to be older than `minimum`. A moat
    /// that doesn't know the command or its `--format json` (an older one)
    /// gives the note, not an error.
    public static func read(minimum: String, version: String?, _ body: () throws -> Value) -> ScreenState {
        let atLeast = MoatVersion.isAtLeast(version, minimum)
        if atLeast == false {
            return .needsNewerMoat(note: MoatRequirement.note(minimum))
        }
        do {
            return try .loaded(body())
        } catch let error as MoatError {
            if atLeast != true, self.looksOlder(error) {
                return .needsNewerMoat(note: MoatRequirement.note(minimum))
            }
            return .failed(message: error.message)
        } catch {
            return .failed(message: "\(error)")
        }
    }

    /// The errors an older moat gives for a command or option it doesn't have.
    static func looksOlder(_ error: MoatError) -> Bool {
        switch error {
        case .unreadable:
            return true
        case let .failed(_, message):
            let text = message.lowercased()
            return ["unrecognized subcommand", "unexpected argument", "invalid value"].contains { text.contains($0) }
        case .notInstalled, .timedOut:
            return false
        }
    }

    public var value: Value? {
        if case let .loaded(value) = self {
            return value
        }
        return nil
    }
}

/// The three detail screens from one read of moat: what you allowed, the
/// brokered secrets and every `openmoat doctor` check.
public struct Details: Equatable {
    public var allowed: ScreenState<AllowedReport>
    public var secrets: ScreenState<SecretList>
    public var checks: ScreenState<DoctorReport>
    public var takenAt: Date

    public init(
        allowed: ScreenState<AllowedReport>,
        secrets: ScreenState<SecretList>,
        checks: ScreenState<DoctorReport>,
        takenAt: Date = Date()
    ) {
        self.allowed = allowed
        self.secrets = secrets
        self.checks = checks
        self.takenAt = takenAt
    }
}
