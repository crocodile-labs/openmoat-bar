import Foundation
import ServiceManagement

/// MoatBar's own settings. These are the only things MoatBar ever saves.
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

    /// Send a notification for blocked calls. Off by default: MoatBar is quiet.
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
                NSLog("MoatBar: open at login: \(error.localizedDescription)")
            }
        }
    }
}
