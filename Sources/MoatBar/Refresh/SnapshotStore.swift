import Foundation
import MoatBarCore

/// Holds the latest read of moat and refreshes it. Reads run off the main
/// thread, one at a time; results are applied on the main thread.
///
/// Requests that arrive while a read is running are coalesced: they all wait
/// for one more read, so a burst of audit-log changes and a manual refresh
/// never stack up reads.
final class SnapshotStore {
    /// Called once a read that covers the request has been applied, with that
    /// read's outcome.
    typealias Completion = (Result<Snapshot, MoatError>) -> Void

    /// The last good read. Kept on screen when a later read fails, except when
    /// moat disappears.
    private(set) var snapshot: Snapshot?
    /// Why the last read failed, if it did.
    private(set) var error: MoatError?
    /// Called on the main thread after every read.
    var onChange: (() -> Void)?
    /// Called on the main thread after every good read, with the read before it.
    var onSnapshot: ((_ old: Snapshot?, _ new: Snapshot) -> Void)?

    private let queue = DispatchQueue(label: "dev.openmoat.moatbar.read", qos: .utility)
    private var timer: Timer?

    /// The read in flight, if any.
    private var reading = false
    /// Requests waiting for the read in flight to finish.
    private var waitingForCurrent: [Completion] = []
    /// Requests that arrived during the read in flight; they need a fresh one.
    private var waitingForNext: [Completion]?

    /// How often moat status is read even when nothing else changes, so a
    /// removed hook shows up within a minute.
    static let statusInterval: TimeInterval = 60

    func start() {
        self.refresh()
        let timer = Timer(timeInterval: Self.statusInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        self.timer?.invalidate()
        self.timer = nil
    }

    /// Read moat. `completion` runs on the main thread after a read that
    /// started after this call has been applied.
    func refresh(completion: Completion? = nil) {
        guard !self.reading else {
            var next = self.waitingForNext ?? []
            if let completion {
                next.append(completion)
            }
            self.waitingForNext = next
            return
        }
        self.reading = true
        if let completion {
            self.waitingForCurrent.append(completion)
        }
        self.queue.async { [weak self] in
            let result = Self.read()
            DispatchQueue.main.async {
                self?.finish(result)
            }
        }
    }

    private func finish(_ result: Result<Snapshot, MoatError>) {
        self.apply(result)
        let done = self.waitingForCurrent
        self.waitingForCurrent = []
        self.reading = false
        done.forEach { $0(result) }
        if let next = self.waitingForNext {
            self.waitingForNext = nil
            self.waitingForCurrent = next
            self.refresh()
        }
    }

    private static func read() -> Result<Snapshot, MoatError> {
        guard let binary = MoatClient.locate() else {
            return .failure(.notInstalled)
        }
        do {
            return try .success(MoatClient(binary: binary).snapshot())
        } catch let error as MoatError {
            return .failure(error)
        } catch {
            return .failure(.unreadable(command: "status"))
        }
    }

    private func apply(_ result: Result<Snapshot, MoatError>) {
        switch result {
        case let .success(snapshot):
            let old = self.snapshot
            self.snapshot = snapshot
            self.error = nil
            self.onSnapshot?(old, snapshot)
        case let .failure(error):
            self.error = error
            if error == .notInstalled {
                self.snapshot = nil
            }
        }
        self.onChange?()
    }
}
