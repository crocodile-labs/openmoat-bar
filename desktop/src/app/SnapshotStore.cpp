#include "app/SnapshotStore.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <QPointer>
#include <QThreadPool>

using namespace std::chrono_literals;

namespace moatbar {
namespace {

/// How often moat status is read even when nothing else changes, so a removed
/// hook shows up within a minute.
constexpr auto kStatusInterval = 60s;
/// Bursts of audit-log writes collapse into one read.
constexpr auto kQuietPeriod = 2s;

Result<Snapshot> readMoat() {
    const auto binary = MoatClient::locate();
    if (!binary) {
        return MoatError{MoatError::Kind::NotInstalled, {}, {}};
    }
    return MoatClient(*binary).snapshot();
}

} // namespace

SnapshotStore::SnapshotStore(QObject *parent) : QObject(parent) {
    m_statusTimer.setInterval(kStatusInterval);
    m_statusTimer.setTimerType(Qt::VeryCoarseTimer);
    connect(&m_statusTimer, &QTimer::timeout, this, &SnapshotStore::refresh);

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(kQuietPeriod);
    connect(&m_debounce, &QTimer::timeout, this, &SnapshotStore::refresh);

    const auto schedule = [this] {
        if (!m_debounce.isActive()) {
            m_debounce.start();
        }
    };
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, schedule);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, schedule);
}

void SnapshotStore::start() {
    watchMoatHome();
    refresh();
    m_statusTimer.start();
}

void SnapshotStore::refresh() {
    if (m_reading) {
        m_again = true;
        return;
    }
    m_reading = true;
    QThreadPool::globalInstance()->start([guard = QPointer<SnapshotStore>(this)] {
        auto result = std::make_shared<Result<Snapshot>>(readMoat());
        // Post back to the GUI thread through the application object, which
        // outlives the store; the guard drops the result if the store is gone.
        QMetaObject::invokeMethod(
            QCoreApplication::instance(),
            [guard, result] {
                if (guard) {
                    guard->apply(std::move(*result));
                }
            },
            Qt::QueuedConnection);
    });
}

void SnapshotStore::apply(Result<Snapshot> result) {
    m_reading = false;
    if (result) {
        std::optional<Snapshot> previous = std::move(m_snapshot);
        m_snapshot = std::move(result).value();
        m_error.reset();
        emit snapshotRead(previous, *m_snapshot);
    } else {
        m_error = result.error();
        if (result.error().kind == MoatError::Kind::NotInstalled) {
            m_snapshot.reset();
        }
    }
    // The audit database may have appeared since the last read.
    watchMoatHome();
    emit changed();
    if (m_again) {
        m_again = false;
        refresh();
    }
}

void SnapshotStore::watchMoatHome() {
    const QString home = moatHome(qEnvironmentVariable("MOAT_HOME"), QDir::homePath());
    QStringList paths{home, QDir(home).filePath(QStringLiteral("audit.db")),
                      QDir(home).filePath(QStringLiteral("audit.db-wal"))};
    paths.removeIf([this](const QString &path) {
        return !QFileInfo::exists(path) || m_watcher.files().contains(path) || m_watcher.directories().contains(path);
    });
    if (!paths.isEmpty()) {
        m_watcher.addPaths(paths);
    }
}

} // namespace moatbar
