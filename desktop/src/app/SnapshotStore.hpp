#pragma once

#include "core/MoatClient.hpp"

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>

#include <memory>
#include <optional>

namespace moatbar {

/// Holds the latest read of moat and refreshes it: when moat's audit log
/// changes (debounced to 2 s), every 60 s, and on request. Reads run on the
/// thread pool, one at a time; results land on the GUI thread.
class SnapshotStore final : public QObject {
    Q_OBJECT

public:
    explicit SnapshotStore(QObject *parent = nullptr);

    void start();
    /// Read moat now. A call while a read is running queues one more read.
    void refresh();

    /// The last good read. Kept when a later read fails, except when moat disappears.
    [[nodiscard]] const std::optional<Snapshot> &snapshot() const noexcept { return m_snapshot; }
    /// Why the last read failed, if it did.
    [[nodiscard]] const std::optional<MoatError> &error() const noexcept { return m_error; }

signals:
    /// After every read.
    void changed();
    /// After every good read, with the read before it.
    void snapshotRead(const std::optional<moatbar::Snapshot> &previous, const moatbar::Snapshot &current);

private:
    void apply(Result<Snapshot> result);
    void watchMoatHome();

    std::optional<Snapshot> m_snapshot;
    std::optional<MoatError> m_error;
    QTimer m_statusTimer;
    QTimer m_debounce;
    QFileSystemWatcher m_watcher;
    bool m_reading = false;
    bool m_again = false;
};

} // namespace moatbar
