import AppKit
import MoatBarCore
import SwiftUI

/// The long view: every decision in a window, filtered by agent, verdict and
/// rule, with one decision in full on the right.
struct ActivityView: View {
    @ObservedObject var model: ActivityModel

    var body: some View {
        VStack(spacing: 0) {
            self.toolbar
            Divider()
            HStack(spacing: 0) {
                self.sidebar.frame(width: 230)
                Divider()
                self.list.frame(minWidth: 340)
                Divider()
                self.detail.frame(width: 360)
            }
        }
        .frame(minWidth: 960, minHeight: 560)
        .onAppear {
            if self.model.readsOnAppear {
                self.model.load()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Window", selection: self.$model.window) {
                ForEach(TimeWindow.allCases) { window in
                    Text(window.title).tag(window)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
            .labelsHidden()

            Picker("Agent", selection: self.$model.filter.host) {
                Text("All agents").tag(String?.none)
                ForEach(self.model.snapshot?.installedAgents ?? [], id: \.host) { agent in
                    Text(agent.name).tag(String?.some(agent.host))
                }
            }
            .frame(width: 170)
            .labelsHidden()

            if self.model.loading {
                ProgressView().controlSize(.small)
            }
            if let error = self.model.error {
                Text(error).font(.caption).foregroundColor(.red).lineLimit(1)
            }
            Spacer()
            Button("Refresh") { self.model.load() }
            Button("Export…") { self.export() }
                .disabled(self.model.rows.isEmpty)
        }
        .padding(12)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        let snapshot = self.model.snapshot
        let counts = snapshot?.counts(for: self.model.filter.host) ?? [:]
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach([Verdict.deny, .ask, .deferred, .allow], id: \.self) { verdict in
                    self.verdictButton(verdict, count: counts[verdict] ?? 0)
                }
                self.verdictButton(nil, count: counts.values.reduce(0, +))
                Divider().padding(.vertical, 6)
                Text("Rules that blocked or asked").font(.caption).foregroundColor(.secondary)
                ForEach(snapshot?.topRules(for: self.model.filter.host).prefix(8) ?? [], id: \.rule) { tally in
                    Button {
                        self.model.filter.rule = self.model.filter.rule == tally.rule ? nil : tally.rule
                    } label: {
                        HStack {
                            Text(tally.rule).font(.system(size: 12, design: .monospaced))
                            Spacer()
                            Text("\(tally.count)").foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(self.model.filter.rule == tally.rule ? .accentColor : .primary)
                }
                Divider().padding(.vertical, 6)
                Text("\(snapshot?.sessions(for: self.model.filter.host).count ?? 0) sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
    }

    private func verdictButton(_ verdict: Verdict?, count: Int) -> some View {
        let on = self.model.filter.verdict == verdict
        return Button {
            self.model.filter.verdict = verdict
            self.model.selectedID = self.model.rows.first?.id
        } label: {
            HStack(spacing: 8) {
                Circle().fill(verdict?.color ?? .secondary).frame(width: 8, height: 8)
                Text(verdict?.title ?? "Everything")
                Spacer()
                Text(Format.count(count)).monospacedDigit()
            }
            .font(.system(size: 13, weight: on ? .semibold : .regular))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color.accentColor.opacity(0.15) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - List and detail

    private var list: some View {
        List(self.model.rows, selection: self.$model.selectedID) { event in
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.truncate(event.display, to: 80))
                    .font(.system(size: 12, design: event.action?.shellCommand != nil ? .monospaced : .default))
                Text(self.rowDetail(event)).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
            .tag(event.id)
        }
        .overlay {
            if self.model.rows.isEmpty, !self.model.loading {
                Text("Nothing here for this window").foregroundColor(.secondary)
            }
        }
    }

    private func rowDetail(_ event: Event) -> String {
        var parts = [event.verdict.title]
        if let rule = event.rule {
            parts.append(rule)
        }
        parts.append(self.model.agentName(event.host))
        parts.append(Format.clock(event.date))
        return parts.joined(separator: " · ")
    }

    private var detail: some View {
        ScrollView {
            if let event = self.model.selected {
                VStack(alignment: .leading, spacing: 10) {
                    DecisionView(
                        event: event,
                        agentName: self.model.agentName(event.host),
                        time: Format.clock(event.date)
                    )
                    HStack {
                        if let action = event.action, let check = CopyCommands.policyCheck(action) {
                            Button("Copy check command") { Actions.copy(check) }
                        }
                        Button("Why? ↗") { Actions.open(DocsLink.blocked) }
                    }
                    if event.verdict == .deny || event.verdict == .ask {
                        Button("Report a wrong block ↗") { Actions.open(DocsLink.reportWrongBlock(rule: event.rule)) }
                            .buttonStyle(.link)
                    }
                }
                .padding(14)
            } else {
                Text("Pick a call to see it in full").foregroundColor(.secondary).padding(20)
            }
        }
    }

    // MARK: - Export

    /// Save the rows shown, one JSON object per line, to a file the person picks.
    private func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "openmoat-bar-activity-\(self.model.window.rawValue).jsonl"
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        let encoder = JSONEncoder()
        let lines = self.model.rows.compactMap { try? encoder.encode($0) }
            .compactMap { String(bytes: $0, encoding: .utf8) }
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
