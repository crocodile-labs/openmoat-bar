import Foundation
import MoatBarCore

/// The Details window's three screens.
enum DetailsTab: String, CaseIterable, Identifiable {
    case allowed
    case secrets
    case checks

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .allowed: return "What you allowed"
        case .secrets: return "Secrets"
        case .checks: return "Checks"
        }
    }
}

/// Loads what you allowed, the brokered secrets and every `openmoat doctor` check
/// for the Details window. Reads run off the main thread; results land on the
/// main thread. Read-only like the rest of OpenMoat Bar.
final class DetailsModel: ObservableObject {
    @Published var tab: DetailsTab = .allowed
    @Published private(set) var details: Details?
    @Published private(set) var loading = false
    /// Why moat couldn't be read at all (not installed).
    @Published private(set) var error: String?
    /// The note for a moat without update notices, from the menu's last read.
    @Published var updateNoticesNote: String?
    /// Agent display names by host id, for session grants.
    @Published var agentNames: [String: String] = [:]

    /// Whether the window reads moat when it appears; off for previews.
    private(set) var readsOnAppear = true

    private let queue = DispatchQueue(label: "dev.openmoat.bar.details", qos: .userInitiated)

    /// Show details without reading moat (README screenshots).
    func show(_ details: Details) {
        self.readsOnAppear = false
        self.details = details
        self.error = nil
    }

    func load() {
        self.loading = true
        self.queue.async {
            let result: Result<Details, MoatError>
            if let binary = MoatClient.locate() {
                // `openmoat doctor` checks every sandbox, which can take a few seconds.
                result = .success(MoatClient(binary: binary, timeout: 15).details())
            } else {
                result = .failure(.notInstalled)
            }
            DispatchQueue.main.async {
                self.loading = false
                switch result {
                case let .success(details):
                    self.details = details
                    self.error = nil
                case let .failure(error):
                    self.error = error.message
                }
            }
        }
    }
}
