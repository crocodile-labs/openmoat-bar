import Foundation

/// What changed between two reads of moat; drives notifications.
public enum Changes {
    /// Agents that are not protected now but were before. On the first read
    /// (`old == nil`) every unprotected agent counts, so a drop that happened
    /// while OpenMoat Bar was not running is still reported once.
    public static func newlyUnprotected(from old: Snapshot?, to new: Snapshot) -> [Protection] {
        let before = Set(old?.unprotected.map(\.host) ?? [])
        return new.unprotected.filter { !before.contains($0.host) }
    }

    /// Blocks recorded since the old read. The first read reports none, so
    /// starting OpenMoat Bar never replays a day's blocks.
    public static func newBlocks(from old: Snapshot?, to new: Snapshot) -> [Event] {
        guard let old else {
            return []
        }
        let seen = old.events.last?.tsMs ?? Int64.min
        let known = Set(old.events.map(\.id))
        return new.events.filter { $0.verdict == .deny && $0.tsMs >= seen && !known.contains($0.id) }
    }
}
