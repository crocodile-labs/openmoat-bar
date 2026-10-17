#include "app/TrayController.hpp"
#include "app/Notify.hpp"
#include "app/TrayIcon.hpp"
#include "app/TrayMenu.hpp"
#include "core/SecurityChecks.hpp"

#include <QApplication>
#include <QMessageBox>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

const QString kSeenUntilKey = QStringLiteral("seenUntilMs");

} // namespace

TrayController::TrayController(SnapshotStore &store, QObject *parent)
    : QObject(parent), m_store(store), m_menu(std::make_unique<QMenu>()), m_quickView(m_model),
      m_activity(m_activityModel, m_model), m_settingsWindows(m_preferences, m_model) {
    m_tray.setContextMenu(m_menu.get());
    m_menu->setToolTipsVisible(true);
    // The menu is never rebuilt while it is open: items removed under the
    // pointer close whatever submenu the person is in. Data that arrives while
    // it is open is applied when it closes.
    connect(m_menu.get(), &QMenu::aboutToHide, this, &TrayController::menuClosed);
    // A click on the icon opens the Quick View; a right click, the menu.
    connect(&m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason != QSystemTrayIcon::Trigger && reason != QSystemTrayIcon::DoubleClick) {
            return;
        }
        // Open and in front: close it. Open behind other windows: bring it up.
        if (m_quickView.isVisible() && m_quickView.window()->isActive()) {
            m_quickView.hide();
        } else if (!m_quickView.justClosed()) {
            openQuickView();
        }
    });
    connect(&m_store, &SnapshotStore::changed, this, &TrayController::storeChanged);
    connect(&m_store, &SnapshotStore::snapshotRead, this, &TrayController::snapshotRead);

    m_model.setRefreshHandler([this] { m_store.refresh(); });
    connect(&m_model, &QuickViewModel::activityRequested, this, &TrayController::openActivity);
    connect(&m_model, &QuickViewModel::settingsRequested, this, &TrayController::openSettings);
    connect(&m_settingsWindows, &SettingsWindows::openRequested, this, &TrayController::openQuickView);
    connect(&m_settingsWindows, &SettingsWindows::quitRequested, qApp, &QCoreApplication::quit);
    connect(&m_model, &QuickViewModel::aboutRequested, this, &TrayController::showAbout);
    connect(&m_model, &QuickViewModel::quitRequested, qApp, &QCoreApplication::quit);
    connect(&m_model, &QuickViewModel::viewClosed, this, &TrayController::markSeen);
    m_model.setData(m_store.snapshot(), m_store.error());

    updateIcon();
    rebuildMenu();
}

void TrayController::show() {
    // Without a tray (GNOME without its extension) MoatBar is its windows and
    // its notifications; launching it again opens the Quick View.
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        m_tray.show();
    }
}

bool TrayController::welcomeOnFirstLaunch() {
    return m_settingsWindows.showWelcomeOnce();
}

void TrayController::handleRequest(const QString &request) {
    if (request == u"show") {
        openQuickView();
    } else if (request == u"activity") {
        openActivity(u"deny"_s);
    } else if (request == u"settings") {
        openSettings();
    } else if (request == u"quit") {
        QApplication::quit();
    }
}

void TrayController::openSettings() {
#ifdef Q_OS_WIN
    m_quickView.hide();
#endif
    m_settingsWindows.showSettings();
}

void TrayController::openQuickView() {
    // Fresh "x min ago" now, fresh data in a moment, as the macOS menu does on open.
    m_model.setData(m_store.snapshot(), m_store.error());
    m_quickView.show(m_tray.geometry());
    m_store.refresh();
}

void TrayController::openActivity(const QString &verdict) {
#ifdef Q_OS_WIN
    // The flyout would close anyway when the window takes focus.
    m_quickView.hide();
#endif
    m_activity.show(verdict);
}

void TrayController::storeChanged() {
    // The Quick View redraws in place; it has no submenus to close.
    m_model.setData(m_store.snapshot(), m_store.error());
    m_model.refreshFinished(m_store.error());
    const auto &snapshot = m_store.snapshot();
    m_preferences.setMoat(MoatClient::locate().value_or(QString{}),
                          snapshot ? snapshot->moatVersion.value_or(QString{}) : QString{});
    updateIcon();
    if (m_menu->isVisible()) {
        m_rebuildPending = true;
    } else {
        rebuildMenu();
    }
}

void TrayController::snapshotRead(const std::optional<Snapshot> &previous, const Snapshot &current) {
    for (const Protection &agent : newlyUnprotected(previous ? &*previous : nullptr, current)) {
        const QString why = agent.reason ? u"OpenMoat says: %1. "_s.arg(*agent.reason) : QString{};
        notify(m_tray, u"%1 is not protected"_s.arg(agent.name),
               why + u"Its calls are not being checked. Open MoatBar for the fix."_s, true);
    }
    if (!m_preferences.notifyBlocks()) {
        return;
    }
    // The rule and the agent, never the command: notifications can show on a
    // locked screen.
    for (const Event &event : newBlocks(previous ? &*previous : nullptr, current)) {
        const QString rule = event.rule().value_or(u"a rule"_s);
        if (!m_throttle.allow(rule)) {
            continue;
        }
        const Protection *agent = current.agent(event.host);
        notify(m_tray, u"Blocked by %1"_s.arg(rule),
               u"%1 was stopped. Open MoatBar to see what and why."_s.arg(agent ? agent->name : event.host), false);
    }
}

void TrayController::updateIcon() {
    const std::optional<Snapshot> &snapshot = m_store.snapshot();
    const bool attention = snapshot && !needingAttention(securityChecks(*snapshot)).empty();
    const IconState state = decideIcon(snapshot ? &*snapshot : nullptr, seenUntilMs(), attention);
    m_tray.setIcon(trayIcon(state));
    m_tray.setToolTip(iconStateLabel(state));
}

void TrayController::rebuildMenu() {
    const std::optional<Snapshot> &snapshot = m_store.snapshot();
    const TrayMenu builder(snapshot ? &*snapshot : nullptr, m_store.error(),
                           TrayActions{
                               .open = [this] { openQuickView(); },
                               .activity = [this] { openActivity(u"deny"_s); },
                               .settings = [this] { openSettings(); },
                               .refresh = [this] { m_store.refresh(); },
                               .about = [this] { showAbout(); },
                               .quit = [] { QApplication::quit(); },
                           });
    builder.fill(*m_menu);
}

void TrayController::markSeen() {
    // Whatever the menu or the Quick View showed has now been seen.
    if (const auto &snapshot = m_store.snapshot()) {
        if (const auto newest = snapshot->newestBlockMs()) {
            setSeenUntilMs(*newest);
        }
    }
    updateIcon();
}

void TrayController::menuClosed() {
    markSeen();
    if (m_rebuildPending) {
        m_rebuildPending = false;
        // After the menu has finished closing.
        QMetaObject::invokeMethod(this, &TrayController::rebuildMenu, Qt::QueuedConnection);
    }
}

void TrayController::showAbout() {
    QMessageBox box;
    box.setWindowTitle(u"About MoatBar"_s);
    box.setIconPixmap(appIcon().pixmap(64, 64));
    box.setText(u"<b>MoatBar</b> %1"_s.arg(QApplication::applicationVersion()));
    box.setInformativeText(u"Shows what OpenMoat does for your coding agents. "
                           u"Read-only: it never changes a rule.<br><br>"
                           u"<a href=\"https://openmoat.dev\">openmoat.dev</a>"_s);
    box.setTextFormat(Qt::RichText);
    box.exec();
}

std::optional<std::int64_t> TrayController::seenUntilMs() const {
    if (!m_settings.contains(kSeenUntilKey)) {
        return std::nullopt;
    }
    return m_settings.value(kSeenUntilKey).toLongLong();
}

void TrayController::setSeenUntilMs(std::int64_t ms) {
    m_settings.setValue(kSeenUntilKey, QVariant::fromValue<qlonglong>(ms));
}

} // namespace moatbar
