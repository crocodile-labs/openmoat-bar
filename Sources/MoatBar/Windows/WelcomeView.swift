import AppKit
import SwiftUI

/// The first-launch window: what MoatBar is, in three lines, then the menu.
struct WelcomeView: View {
    @ObservedObject var preferences: Preferences
    let onOpenMenu: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let logo = AppResources.image("logo-float") {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .accessibilityLabel("OpenMoat")
            }
            Text("Welcome to MoatBar").font(.system(size: 22, weight: .bold))
            Text("See what OpenMoat does for your coding agents.")
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 14) {
                self.point(
                    "xmark.octagon",
                    color: .red,
                    title: "What was blocked, and why",
                    text: "Every stop with its rule and the plain reason your agent was given."
                )
                self.point(
                    "checkmark.shield",
                    color: .green,
                    title: "Whether each agent is protected",
                    text: "Checked every minute. You hear about it if one drops."
                )
                self.point(
                    "eye",
                    color: .blue,
                    title: "Read-only",
                    text: "MoatBar never allows anything or changes a rule. Fixes are commands you copy."
                )
            }
            .padding(.vertical, 12)
            if self.preferences.canOpenAtLogin {
                Toggle("Open MoatBar at login", isOn: Binding(
                    get: { self.preferences.openAtLogin },
                    set: { self.preferences.openAtLogin = $0 }
                ))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Quit", action: self.onQuit)
                Button("Open the menu", action: self.onOpenMenu)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 460)
    }

    private func point(_ symbol: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(text).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 13))
    }
}
