import AppKit
import MoatBarCore
import SwiftUI

/// Settings: the few things OpenMoat Bar itself decides. Nothing here changes OpenMoat.
struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    let moatPath: String?
    let moatVersion: String?

    var body: some View {
        Form {
            Section {
                if self.preferences.canOpenAtLogin {
                    Toggle("Open at login", isOn: Binding(
                        get: { self.preferences.openAtLogin },
                        set: { self.preferences.openAtLogin = $0 }
                    ))
                } else {
                    Text("Open at login: add OpenMoat Bar in System Settings → General → Login Items.")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("General").font(.headline)
            }

            Section {
                Toggle("An agent is not protected", isOn: .constant(true))
                    .disabled(true)
                Text("Always on: the one thing OpenMoat Bar must never miss.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Toggle("Each blocked call", isOn: Binding(
                    get: { self.preferences.notifyBlocks },
                    set: { self.preferences.notifyBlocks = $0 }
                ))
                Text("At most one per rule every 10 minutes. Shows the rule and the agent, never the command.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Notifications").font(.headline)
            }

            Section {
                Text("openmoat: \(self.moatPath ?? "not found")\(self.moatVersion.map { " · \($0)" } ?? "")")
                    .textSelection(.enabled)
                Text("OpenMoat Bar reads OpenMoat's status and audit log. It never writes to them.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("How to turn OpenMoat off ↗") {
                    Actions.open(DocsLink.turnOff)
                }
                .buttonStyle(.link)
            } header: {
                Text("OpenMoat").font(.headline)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
