import AppKit
import MoatBarCore
import SwiftUI

/// Width of the menu's custom rows.
let menuWidth: CGFloat = 330

/// Colours for verdicts, shared by the menu and the icon.
extension Verdict {
    var color: Color {
        switch self {
        case .deny: return Color(nsColor: .systemRed)
        case .ask: return Color(nsColor: .systemOrange)
        case .deferred: return Color(nsColor: .systemBlue)
        case .allow: return Color(nsColor: .systemGreen)
        }
    }
}

extension Level {
    var color: Color {
        switch self {
        case .hookAndOsSandbox: return Color(nsColor: .systemGreen)
        case .hookOnly: return Color(nsColor: .systemOrange)
        case .notProtected: return Color(nsColor: .systemRed)
        case .notSetUp, .notFound, .unknown: return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

/// A SwiftUI view as a menu item, sized to its content at the menu width.
func hostedItem(_ view: some View, width: CGFloat = menuWidth) -> NSMenuItem {
    let host = NSHostingView(rootView: view.frame(width: width - 28, alignment: .leading).padding(.horizontal, 14))
    host.frame.size = host.fittingSize
    let item = NSMenuItem()
    item.view = host
    return item
}

// MARK: - Header

struct HeaderView: View {
    let title: String
    let trailing: String
    let updated: String
    /// Protection in a few words ("2 of 2 protected", "Hook + sandbox").
    let detail: String
    /// The protection colour behind `detail`.
    var detailColor: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(self.title).font(.system(size: 15, weight: .bold))
                Spacer()
                Text(self.trailing).font(.system(size: 11)).foregroundColor(.secondary)
            }
            HStack {
                Text(self.updated).font(.system(size: 12)).foregroundColor(.secondary)
                Spacer()
                Text(self.detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(self.detailColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(self.detailColor.opacity(0.14)))
            }
        }
        .padding(.vertical, 4)
    }
}

/// A small uppercase label above a group of rows.
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(self.title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
            Spacer()
            if let trailing = self.trailing {
                Text(trailing).font(.system(size: 11))
            }
        }
        .foregroundColor(.secondary)
        .padding(.top, 6)
        .padding(.bottom, 1)
    }
}

// MARK: - Today bar

/// Calls per hour today, stacked by verdict, blocks on top.
struct TodayBar: View {
    let hours: [[Verdict: Int]]
    let total: Int
    let sessions: Int
    let currentHour: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(self.total) calls · \(self.sessions) sessions")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        self.bar(hour, height: geo.size.height)
                            .opacity(hour > self.currentHour ? 0.35 : 1)
                    }
                }
            }
            .frame(height: 30)
            HStack {
                ForEach(["00", "06", "12", "18", "24"], id: \.self) { label in
                    Text(label)
                    if label != "24" {
                        Spacer()
                    }
                }
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today: \(self.total) calls")
    }

    private var peak: Int {
        max(1, self.hours.map { $0.values.reduce(0, +) }.max() ?? 1)
    }

    private func bar(_ hour: Int, height: CGFloat) -> some View {
        let counts = self.hours[hour]
        return VStack(spacing: 0) {
            ForEach([Verdict.deny, .ask, .deferred, .allow], id: \.self) { verdict in
                let n = counts[verdict] ?? 0
                if n > 0 {
                    Rectangle()
                        .fill(verdict.color)
                        .frame(height: max(verdict == .deny ? 3 : 1, height * CGFloat(n) / CGFloat(self.peak)))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: height, alignment: .bottom)
        .background(RoundedRectangle(cornerRadius: 1).fill(Color.primary.opacity(0.06)))
    }
}

// MARK: - Problem card

/// A problem at the top of the menu: what happened, what it means, one fix.
/// The fix to copy goes in a `CopyMenuRow` right below the card, so the menu
/// stays open when it is copied.
struct ProblemCard: View {
    let title: String
    let text: String
    let note: String
    var tint: Color = .init(nsColor: .systemRed)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(self.tint).frame(width: 8, height: 8)
                Text(self.title).font(.system(size: 13, weight: .bold))
            }
            Text(self.text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Text(self.note).font(.system(size: 11)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 9).fill(self.tint.opacity(0.12)))
        .padding(.vertical, 4)
    }
}

// MARK: - Decision

/// One call in full: what ran, the rule, what the agent was told, and why.
struct DecisionView: View {
    let event: Event
    let agentName: String
    let time: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(self.event.verdict.color).frame(width: 9, height: 9)
                    Text(self.event.verdict.title).font(.system(size: 15, weight: .bold))
                        .foregroundColor(self.event.verdict.color)
                }
                Spacer()
                if let rule = self.event.rule {
                    Text(rule)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().stroke(Color.secondary.opacity(0.4)))
                }
            }
            Text("\(self.agentName) · \(self.time) · \(self.event.tool)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(self.event.display)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(4)
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            if let unseen = self.event.action?.uncheckedReason {
                self.row("Couldn't see", unseen)
            }
            if let cwd = self.event.cwd {
                self.row("Folder", cwd)
            }
            if let reason = self.event.reason {
                self.row("Agent was told", reason)
            }
            if let rule = self.event.rule, let why = RuleText.why(rule) {
                Text("Why: ").font(.system(size: 12, weight: .semibold))
                    + Text(why).font(.system(size: 12))
            }
            if let note = RuleText.driftNote(self.event.rules) {
                Text("Note: ").font(.system(size: 12, weight: .semibold))
                    + Text(note).font(.system(size: 12))
            }
        }
        .padding(.vertical, 6)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundColor(.secondary).frame(width: 92, alignment: .leading)
            Text(value).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }
}

// MARK: - Agent detail

struct AgentDetailView: View {
    let agent: Protection
    let lastCall: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(self.agent.name).font(.system(size: 15, weight: .bold))
                Spacer()
                Text(self.agent.level.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(self.agent.level.color)
            }
            if let reason = self.agent.reason {
                Text(reason).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            }
            if self.agent.level == .notFound {
                Text("\(self.agent.name) isn't installed on this Mac. Once it is, run openmoat to protect it.")
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let lastCall = self.lastCall {
                Text("Last call \(lastCall)").font(.system(size: 12)).foregroundColor(.secondary)
            }
            if !self.agent.gaps.isEmpty {
                Text("Not covered: ").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    + Text(self.agent.gaps).font(.system(size: 11)).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
