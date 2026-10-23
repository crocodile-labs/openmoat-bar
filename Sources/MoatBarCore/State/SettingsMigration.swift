import Foundation

/// The app was called MoatBar until 0.3.0, with the bundle id
/// `dev.openmoat.moatbar`, so its settings sit under that name. On the first
/// start as OpenMoat Bar they are copied over once, so nobody loses a setting.
public enum SettingsMigration {
    /// The old app's settings domain (its bundle id).
    public static let oldDomain = "dev.openmoat.moatbar"
    /// Set in the new settings once the copy ran, so it runs only once.
    public static let doneKey = "migratedFromMoatBar"
    /// Every setting the app saves: notifications, welcome shown, agent tab,
    /// the newest event seen.
    public static let keys = ["notifyBlocks", "welcomed", "selectedHost", "seenUntilMs"]

    /// What to write into the new settings: the old value of every known key
    /// the new settings do not have yet, plus `doneKey`. Empty once done.
    /// - Parameters:
    ///   - old: the old domain, or `nil` when the old app never ran.
    ///   - current: the new domain as it is now.
    public static func values(old: [String: Any]?, current: [String: Any]) -> [String: Any] {
        guard current[self.doneKey] == nil else {
            return [:]
        }
        var out: [String: Any] = [self.doneKey: true]
        for key in self.keys where current[key] == nil {
            if let value = old?[key] {
                out[key] = value
            }
        }
        return out
    }
}
