import Foundation
import MoatBarCore

/// Loads a window of events for the Activity window. Reads run off the main
/// thread; results land on the main thread.
final class ActivityModel: ObservableObject {
    @Published var window: TimeWindow = .today {
        didSet { self.load() }
    }

    @Published var filter = ActivityFilter()
    @Published var selectedID: String?
    @Published private(set) var snapshot: Snapshot?
    @Published private(set) var loading = false
    @Published private(set) var error: String?

    /// Most rows the list shows; counts still cover every event.
    static let rowLimit = 500

    private let queue = DispatchQueue(label: "dev.openmoat.bar.activity", qos: .userInitiated)

    var rows: [Event] {
        Array(self.filter.apply(self.snapshot?.events ?? []).prefix(Self.rowLimit))
    }

    var selected: Event? {
        guard let id = self.selectedID else {
            return nil
        }
        return self.snapshot?.events.first { $0.id == id }
    }

    /// Whether the window reads moat when it appears; off for previews.
    private(set) var readsOnAppear = true

    /// Show a snapshot without reading moat (README screenshots).
    func show(_ snapshot: Snapshot) {
        self.readsOnAppear = false
        self.snapshot = snapshot
        self.error = nil
        self.selectedID = self.rows.first?.id
    }

    func load() {
        self.loading = true
        let window = self.window
        self.queue.async {
            let result: Result<Snapshot, MoatError>
            if let binary = MoatClient.locate() {
                let client = MoatClient(binary: binary, timeout: 15)
                do {
                    result = try .success(Snapshot(status: client.status(), events: client.events(since: window)))
                } catch let error as MoatError {
                    result = .failure(error)
                } catch {
                    result = .failure(.unreadable(command: "show"))
                }
            } else {
                result = .failure(.notInstalled)
            }
            DispatchQueue.main.async {
                self.loading = false
                switch result {
                case let .success(snapshot):
                    self.snapshot = snapshot
                    self.error = nil
                    if self.selectedID == nil {
                        self.selectedID = self.rows.first?.id
                    }
                case let .failure(error):
                    self.error = error.message
                }
            }
        }
    }

    func agentName(_ host: String) -> String {
        self.snapshot?.agentName(host) ?? HostText.name(forOther: host)
    }
}
