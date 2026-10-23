import Foundation
import MoatBarCore
import ServiceManagement

/// OpenMoat Bar's own settings. These are the only things OpenMoat Bar ever saves.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults: UserDefaults

    private enum Key {
        static let notifyBlocks = "notifyBlocks"
        static let welcomed = "welcomed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Copies the settings saved under the old name, MoatBar, once. Runs
    /// before anything reads a setting.
    static func migrateFromMoatBar(defaults: UserDefaults = .standard) {
        guard let domain = Bundle.main.bundleIdentifier, domain != SettingsMigration.oldDomain else {
            return
        }
        let values = SettingsMigration.values(
            old: defaults.persistentDomain(forName: SettingsMigration.oldDomain),
            current: defaults.persistentDomain(forName: domain) ?? [:]
        )
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
    }

    /// Send a notification for blocked calls. Off by default: OpenMoat Bar is quiet.
    var notifyBlocks: Bool {
        get { self.defaults.bool(forKey: Key.notifyBlocks) }
        set {
            self.objectWillChange.send()
            self.defaults.set(newValue, forKey: Key.notifyBlocks)
        }
    }

    /// The welcome window was shown once.
    var welcomed: Bool {
        get { self.defaults.bool(forKey: Key.welcomed) }
        set { self.defaults.set(newValue, forKey: Key.welcomed) }
    }

    // MARK: - Open at login

    /// Whether "Open at login" can be set from here (macOS 13 and later).
    var canOpenAtLogin: Bool {
        if #available(macOS 13.0, *) {
            return Bundle.main.bundleIdentifier != nil
        }
        return false
    }

    var openAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return false
        }
        set {
            guard #available(macOS 13.0, *) else {
                return
            }
            self.objectWillChange.send()
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("OpenMoat Bar: open at login: \(error.localizedDescription)")
            }
        }
    }
}
