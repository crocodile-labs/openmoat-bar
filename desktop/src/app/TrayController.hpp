#pragma once

#include "app/QuickView.hpp"
#include "app/QuickViewModel.hpp"
#include "app/SnapshotStore.hpp"

#include <QMenu>
#include <QObject>
#include <QSettings>
#include <QSystemTrayIcon>

#include <cstdint>
#include <memory>
#include <optional>

namespace moatbar {

/// Owns the tray icon, the Quick View (a click on the icon) and the tray menu
/// (a right click): draws the icon from the latest snapshot, rebuilds the menu
/// when data changes (never while it is open), and sends the one notification
/// MoatBar always sends, when an agent stops being protected.
class TrayController final : public QObject {
    Q_OBJECT

public:
    explicit TrayController(SnapshotStore &store, QObject *parent = nullptr);

    void show();
    void openQuickView();

private:
    void storeChanged();
    void snapshotRead(const std::optional<Snapshot> &previous, const Snapshot &current);
    void updateIcon();
    void rebuildMenu();
    void menuClosed();
    void markSeen();
    void showAbout();

    [[nodiscard]] std::optional<std::int64_t> seenUntilMs() const;
    void setSeenUntilMs(std::int64_t ms);

    SnapshotStore &m_store;
    QSystemTrayIcon m_tray;
    std::unique_ptr<QMenu> m_menu;
    QuickViewModel m_model;
    QuickView m_quickView;
    QSettings m_settings;
    bool m_rebuildPending = false;
};

} // namespace moatbar
