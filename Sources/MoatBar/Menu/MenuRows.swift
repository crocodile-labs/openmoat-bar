import AppKit
import MoatBarCore
import SwiftUI

/// The chevron AppKit draws for a submenu; view-based rows draw their own.
struct SubmenuChevron: View {
    let highlighted: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(RowStyle.secondary(self.highlighted))
    }
}

/// The agent's icon (Claude, Codex, Cursor), drawn in the row's text colour.
struct AgentIcon: View {
    let host: String
    var size: CGFloat = 14
    var color: Color = .primary

    var body: some View {
        if let image = AppResources.agentIcon(self.host) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: self.size, height: self.size)
                .foregroundColor(self.color)
        } else {
            Image(systemName: "terminal")
                .font(.system(size: self.size * 0.8))
                .foregroundColor(self.color)
        }
    }
}

/// "Blocked  3" with its one-line meaning.
struct VerdictRow: View {
    @ObservedObject var state: MenuRowState
    let verdict: Verdict
    let count: Int

    var body: some View {
        let on = self.state.highlighted
        HStack(spacing: 10) {
            Circle().fill(RowStyle.tint(on, self.verdict.color)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(self.verdict.title).font(.system(size: 13, weight: .semibold))
                    .foregroundColor(RowStyle.primary(on))
                Text(self.verdict.subtitle).font(.system(size: 11))
                    .foregroundColor(RowStyle.secondary(on))
            }
            Spacer(minLength: 8)
            Text(Format.count(self.count))
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundColor(RowStyle.primary(on))
            SubmenuChevron(highlighted: on)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

/// One agent: icon, name, level, today's numbers and last call.
struct AgentRow: View {
    @ObservedObject var state: MenuRowState
    let agent: Protection
    let counts: [Verdict: Int]
    let lastCall: String?

    var body: some View {
        let on = self.state.highlighted
        HStack(alignment: .top, spacing: 10) {
            AgentIcon(host: self.agent.host, size: 16, color: RowStyle.tint(on, self.agent.level.color))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(self.agent.name).font(.system(size: 13, weight: .semibold))
                        .foregroundColor(RowStyle.primary(on))
                    Spacer()
                    Text(self.agent.level.label).font(.system(size: 11, weight: .medium))
                        .foregroundColor(RowStyle.tint(on, self.levelColor))
                }
                Text(self.detail).font(.system(size: 11)).foregroundColor(RowStyle.secondary(on))
            }
            SubmenuChevron(highlighted: on).padding(.top, 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private var levelColor: Color {
        self.agent.level == .notProtected ? Level.notProtected.color : Color(nsColor: .secondaryLabelColor)
    }

    private var detail: String {
        if self.agent.level == .notSetUp {
            return "Run moat in Terminal to protect it"
        }
        let calls = self.counts.values.reduce(0, +)
        var line = "Blocked \(self.counts[.deny] ?? 0) · Asked \(self.counts[.ask] ?? 0) · \(Format.count(calls)) calls"
        if let lastCall = self.lastCall {
            line += " · \(lastCall)"
        }
        return line
    }
}

/// One call in a list: what ran, then rule, agent, folder and time.
struct EventRow: View {
    @ObservedObject var state: MenuRowState
    let event: Event
    let agentName: String

    var body: some View {
        let on = self.state.highlighted
        HStack(alignment: .top, spacing: 10) {
            AgentIcon(host: self.event.host, size: 13, color: RowStyle.secondary(on)).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(Format.truncate(self.event.display, to: 56))
                    .font(.system(size: 12, design: self.event.action?.shellCommand != nil ? .monospaced : .default))
                    .foregroundColor(RowStyle.primary(on))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let rule = self.event.rule {
                        Text(rule)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().stroke(RowStyle.secondary(on).opacity(0.6)))
                    }
                    Text(self.place).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Format.clock(self.event.date)).monospacedDigit()
                }
                .font(.system(size: 11))
                .foregroundColor(RowStyle.secondary(on))
            }
            SubmenuChevron(highlighted: on).padding(.top, 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private var place: String {
        let folder = self.event.cwd.map(Format.shortPath)
        return [self.agentName, folder].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A plain action row: label on the left, an optional shortcut hint on the right.
struct ActionRow: View {
    @ObservedObject var state: MenuRowState
    let title: String
    var symbol: String?
    var hint: String?

    var body: some View {
        let on = self.state.highlighted
        HStack(spacing: 8) {
            if let symbol = self.symbol {
                Image(systemName: symbol).font(.system(size: 12)).frame(width: 16)
                    .foregroundColor(RowStyle.secondary(on))
            }
            Text(self.title).font(.system(size: 13)).foregroundColor(RowStyle.primary(on))
            Spacer()
            if let hint = self.hint {
                Text(hint).font(.system(size: 12)).foregroundColor(RowStyle.secondary(on))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
