import AppKit
import MoatBarCore
import SwiftUI

/// What you allowed, the brokered secrets and every `moat doctor` check, one
/// screen each. Nothing here changes OpenMoat: each change is a command to copy.
struct DetailsView: View {
    @ObservedObject var model: DetailsModel
    /// When "ends in" is counted from; `nil` for the current time.
    var now: Date?

    var body: some View {
        VStack(spacing: 0) {
            self.toolbar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    self.content
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear {
            if self.model.readsOnAppear, self.model.details == nil, !self.model.loading {
                self.model.load()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Screen", selection: self.$model.tab) {
                ForEach(DetailsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 340)
            .labelsHidden()
            if self.model.loading {
                ProgressView().controlSize(.small)
            }
            Spacer()
            Button("Refresh") { self.model.load() }
        }
        .padding(12)
    }

    @ViewBuilder private var content: some View {
        if let error = self.model.error {
            DetailsNote(text: error, color: Color(nsColor: .systemOrange))
        } else if let details = self.model.details {
            switch self.model.tab {
            case .allowed: self.screen(details.allowed) { self.allowed($0) }
            case .secrets: self.screen(details.secrets) { self.secrets($0) }
            case .checks: self.screen(details.checks) { self.checks($0) }
            }
        } else {
            Text("Reading moat…").foregroundColor(.secondary)
        }
    }

    // swiftformat:disable opaqueGenericParameters
    // `Loaded` is the result type of a closure parameter, where Swift 5.7 has
    // no `some View`.

    /// The loaded screen, or the note for an older moat, or why moat couldn't be read.
    @ViewBuilder
    private func screen<Value: Equatable, Loaded: View>(
        _ state: ScreenState<Value>,
        @ViewBuilder loaded: (Value) -> Loaded
    ) -> some View {
        // swiftformat:enable opaqueGenericParameters
        switch state {
        case let .loaded(value):
            loaded(value)
        case let .needsNewerMoat(note):
            DetailsNote(text: note, color: .secondary)
        case let .failed(message):
            DetailsNote(text: "\(message). moat doctor shows what is wrong.", color: Color(nsColor: .systemOrange))
        }
    }

    // MARK: - What you allowed

    private func allowed(_ report: AllowedReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DetailsSection(title: "Permanent rules", count: report.rules.count) {
                if report.rules.isEmpty {
                    DetailsEmpty(text: "None. moat allow --always, --site and --dir add them.")
                }
                ForEach(report.rules) { rule in
                    DetailsRow(title: rule.id, monospaced: true, lines: self.ruleLines(rule)) {
                        CopyButton(title: "Copy the remove command", command: CopyCommands.removeRule(rule.id))
                    }
                }
            }
            DetailsSection(title: "Session grants", count: report.sessionGrants.count) {
                if report.sessionGrants.isEmpty {
                    DetailsEmpty(text: "None. moat allow --last allows one call again for the rest of its session.")
                }
                ForEach(report.sessionGrants) { grant in
                    DetailsRow(title: grant.what, monospaced: true, lines: [self.grantLine(grant)])
                }
            }
            DetailsSection(title: "Trusted repositories", count: report.trustedRepos.count) {
                if report.trustedRepos.isEmpty {
                    DetailsEmpty(text: "None. moat trust lets a repository's own policy allow calls.")
                }
                ForEach(report.trustedRepos) { repo in
                    DetailsRow(
                        title: Format.shortPath(repo.root),
                        monospaced: true,
                        lines: [self.trustLine(repo)]
                    ) {
                        CopyButton(title: "Copy the revoke command", command: CopyCommands.revokeTrust(repo.root))
                    }
                }
            }
        }
    }

    private func ruleLines(_ rule: AllowedRule) -> [String] {
        (rule.reason.map { [$0] } ?? []) + rule.patterns.map(DetailsText.patternsLine)
    }

    private func grantLine(_ grant: SessionGrant) -> String {
        let agent = self.model.agentNames[grant.host] ?? grant.host
        let session = String(grant.sessionId.prefix(8))
        let now = self.now ?? Date()
        let ends = DetailsText.endsIn(grant.expiresAtMs, nowMs: Int64(now.timeIntervalSince1970 * 1000))
        return "\(agent) · session \(session) · \(ends)"
    }

    private func trustLine(_ repo: TrustedRepo) -> String {
        "Policy file sha256 \(DetailsText.shortHash(repo.sha256)). A change to it ends the trust."
    }

    // MARK: - Secrets

    private func secrets(_ list: SecretList) -> some View {
        DetailsSection(title: "Brokered secrets", count: list.secrets.count) {
            if list.secrets.isEmpty {
                DetailsEmpty(text: "None. moat secret add keeps a token away from the agent and adds it to requests.")
            }
            ForEach(list.secrets) { secret in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        StatusDot(color: Color(nsColor: secret.sourceExposed ? .systemOrange : .systemGreen))
                        Text(secret.id).font(.system(size: 13, weight: .semibold, design: .monospaced))
                        Text(secret.host).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    Text(DetailsText.secretLine(secret)).font(.system(size: 12))
                    Text(secret.sourceExposed ? DetailsText.exposedHint : DetailsText.coveredHint)
                        .font(.system(size: 12))
                        .foregroundColor(secret.sourceExposed ? Color(nsColor: .systemOrange) : .secondary)
                    if secret.plainHttp {
                        Text(DetailsText.plainHttpHint).font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    if secret.sourceExposed {
                        CopyButton(title: "Copy the check command", command: DetailsText.lint)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Checks

    private func checks(_ report: DoctorReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let note = self.model.updateNoticesNote {
                DetailsNote(text: note, color: .secondary)
            }
            Text(report.problems == 0 ? "No problems" : "\(report.problems) to fix")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(report.problems == 0 ? Color(nsColor: .systemGreen) : Color(nsColor: .systemRed))
            ForEach(report.groups) { group in
                DetailsSection(title: group.status.title, count: group.checks.count) {
                    ForEach(Array(group.checks.enumerated()), id: \.offset) { _, check in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            StatusDot(color: group.status.color)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(check.title).font(.system(size: 12, weight: .medium))
                                if !check.subtitle.isEmpty {
                                    Text(check.subtitle).font(.system(size: 12)).foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }
            }
            CopyButton(title: "Copy for every check", command: CopyCommands.doctor)
        }
    }
}

extension DoctorStatus {
    var color: Color {
        switch self {
        case .problem: return Color(nsColor: .systemRed)
        case .warning: return Color(nsColor: .systemOrange)
        case .note: return Color(nsColor: .systemBlue)
        case .ok: return Color(nsColor: .systemGreen)
        }
    }
}

// MARK: - Pieces

/// A heading with a count over a group of rows.
private struct DetailsSection<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: self.title, trailing: "\(self.count)")
            self.content()
        }
    }
}

/// One item: a title and lines under it, with an optional button.
private struct DetailsRow<Accessory: View>: View {
    let title: String
    var monospaced = false
    let lines: [String]
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(self.title)
                .font(.system(size: 13, weight: .semibold, design: self.monospaced ? .monospaced : .default))
                .textSelection(.enabled)
            ForEach(Array(self.lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.system(size: 12)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            self.accessory()
        }
        .padding(.vertical, 2)
    }
}

extension DetailsRow where Accessory == EmptyView {
    init(title: String, monospaced: Bool = false, lines: [String]) {
        self.init(title: title, monospaced: monospaced, lines: lines) { EmptyView() }
    }
}

private struct DetailsEmpty: View {
    let text: String

    var body: some View {
        Text(self.text).font(.system(size: 12)).foregroundColor(.secondary)
    }
}

/// A line that stands in for a screen: an older moat, or moat unreadable.
private struct DetailsNote: View {
    let text: String
    let color: Color

    var body: some View {
        Text(self.text)
            .font(.system(size: 13))
            .foregroundColor(self.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle().fill(self.color).frame(width: 8, height: 8)
    }
}

/// Copies a command and says so for a moment.
private struct CopyButton: View {
    let title: String
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Button(self.copied ? "Copied ✓" : self.title) {
                Actions.copy(self.command)
                self.copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.copied = false }
            }
            Text(self.command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
