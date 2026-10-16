import CoreServices
import Foundation
import MoatBarCore

/// Calls back when moat's audit log changes, so new calls show up within
/// seconds instead of on the next minute tick. Watches the moat directory with
/// FSEvents (it survives the database being replaced) and coalesces bursts.
final class AuditWatcher {
    private var stream: FSEventStreamRef?
    private let directory: URL
    private let onChange: () -> Void
    private var pending: DispatchWorkItem?

    /// At most one callback per this many seconds.
    static let quietPeriod: TimeInterval = 2

    init(directory: URL = MoatHome.directory(), onChange: @escaping () -> Void) {
        self.directory = directory
        self.onChange = onChange
    }

    deinit {
        self.stop()
    }

    func start() {
        guard self.stream == nil else {
            return
        }
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else {
                return
            }
            let watcher = Unmanaged<AuditWatcher>.fromOpaque(info).takeUnretainedValue()
            let names = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            if names.prefix(count).contains(where: { $0.contains("audit.db") }) {
                watcher.schedule()
            }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [self.directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else {
            return
        }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        guard let stream = self.stream else {
            return
        }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func schedule() {
        guard self.pending == nil else {
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            self?.onChange()
        }
        self.pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.quietPeriod, execute: work)
    }
}
