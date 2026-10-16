#include "app/TrayController.hpp"
#include "app/TrayIcon.hpp"
#include "app/TrayMenu.hpp"
#include "core/SecurityChecks.hpp"

#include <QApplication>
#include <QCursor>
#include <QMessageBox>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

const QString kSeenUntilKey = QStringLiteral("seenUntilMs");

} // namespace

TrayController::TrayController(SnapshotStore &store, QObject *parent)
    : QObject(parent), m_store(store), m_menu(std::make_unique<QMenu>()) {
    m_tray.setContextMenu(m_menu.get());
    m_menu->setToolTipsVisible(true);
    // The menu is never rebuilt while it is open: items removed under the
    // pointer close whatever submenu the person is in. Data that arrives while
    // it is open is applied when it closes.
    connect(m_menu.get(), &QMenu::aboutToHide, this, &TrayController::menuClosed);
    // Windows opens the context menu on right click only; a left click opens it too.
    connect(&m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger) {
            m_menu->popup(QCursor::pos());
        }
    });
    connect(&m_store, &SnapshotStore::changed, this, &TrayController::storeChanged);
    connect(&m_store, &SnapshotStore::snapshotRead, this, &TrayController::snapshotRead);
    updateIcon();
    rebuildMenu();
}

void TrayController::show() {
    m_tray.show();
}

void TrayController::storeChanged() {
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
        m_tray.showMessage(u"%1 is not protected"_s.arg(agent.name),
                           why + u"Its calls are not being checked. Open MoatBar for the fix."_s,
                           QSystemTrayIcon::Warning);
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
                               .refresh = [this] { m_store.refresh(); },
                               .about = [this] { showAbout(); },
                               .quit = [] { QApplication::quit(); },
                           });
    builder.fill(*m_menu);
}

void TrayController::menuClosed() {
    // Whatever was in the menu has now been seen.
    if (const auto &snapshot = m_store.snapshot()) {
        if (const auto newest = snapshot->newestBlockMs()) {
            setSeenUntilMs(*newest);
        }
    }
    updateIcon();
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
