#pragma once

#include "app/ActivityWindow.hpp"
#include "app/Preferences.hpp"
#include "app/QuickView.hpp"
#include "app/QuickViewModel.hpp"
#include "app/SettingsWindows.hpp"
#include "app/SnapshotStore.hpp"
#include "core/RuleThrottle.hpp"

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
/// when data changes (never while it is open), and sends notifications: always
/// when an agent stops being protected; for blocked calls only if turned on in
/// Settings, at most one per rule every 10 minutes, never with the command.
class TrayController final : public QObject {
    Q_OBJECT

public:
    explicit TrayController(SnapshotStore &store, QObject *parent = nullptr);

    void show();
    /// The welcome window on the first launch; nothing after that.
    void welcomeOnFirstLaunch();
    void openQuickView();
    void openActivity(const QString &verdict);
    void openSettings();

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
    ActivityModel m_activityModel;
    ActivityWindow m_activity;
    Preferences m_preferences;
    SettingsWindows m_settingsWindows;
    RuleThrottle m_throttle;
    QSettings m_settings;
    bool m_rebuildPending = false;
};

} // namespace moatbar
