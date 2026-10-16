import Foundation
import MoatBarCore

/// Holds the latest read of moat and refreshes it. Reads run off the main
/// thread, one at a time; results are applied on the main thread.
final class SnapshotStore {
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
    private var reading = false
    private var again = false
    private var timer: Timer?

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

    /// Read moat now. A call while a read is running queues one more read.
    func refresh() {
        guard !self.reading else {
            self.again = true
            return
        }
        self.reading = true
        self.queue.async {
            let result = Self.read()
            DispatchQueue.main.async {
                self.apply(result)
                self.reading = false
                if self.again {
                    self.again = false
                    self.refresh()
                }
            }
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
