import Foundation
import MoatBarCore
import UserNotifications

/// Sends the one notification MoatBar always sends: an agent stopped being
/// protected. Quiet otherwise: allowed calls and calls left to the agent never
/// notify, because the agent already asks the person about those.
final class Notifier {
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
                body: "\(why)Its calls are not being checked. Open MoatBar for the fix."
            )
        }
    }

    private func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        self.center?.add(request)
    }
}
