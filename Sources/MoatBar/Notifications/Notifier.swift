import Foundation
import MoatBarCore
import UserNotifications

/// Notifications. Always: an agent stopped being protected. Opt-in: blocked
/// calls, at most one per rule every 10 minutes, naming the rule and the agent
/// but never the command. Allowed calls and calls left to the agent never
/// notify, because the agent already asks the person about those.
final class Notifier {
    private let preferences: Preferences
    private var throttle = RuleThrottle()

    init(preferences: Preferences = .shared) {
        self.preferences = preferences
    }

    /// Notifications need a bundled app; a bare `swift run` binary has none.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func requestPermission() {
        self.center?.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Called after every read with the read before it.
    func changed(from old: Snapshot?, to new: Snapshot) {
        for agent in Changes.newlyUnprotected(from: old, to: new) {
            let why = agent.reason.map { "OpenMoat says: \($0). " } ?? ""
            self.post(
                id: "unprotected-\(agent.host)",
                title: "\(agent.name) is not protected",
                body: "\(why)Its calls are not being checked. Open MoatBar for the fix.",
                sound: true
            )
        }
        guard self.preferences.notifyBlocks else {
            return
        }
        for event in Changes.newBlocks(from: old, to: new) {
            let rule = event.rule ?? "a rule"
            guard self.throttle.allow(rule) else {
                continue
            }
            let agent = new.agent(event.host)?.name ?? event.host
            self.post(
                id: "block-\(event.id)",
                title: "Blocked by \(rule)",
                body: "\(agent) was stopped. Open MoatBar to see what and why.",
                sound: false
            )
        }
    }

    private func post(id: String, title: String, body: String, sound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        self.center?.add(request)
    }
}
