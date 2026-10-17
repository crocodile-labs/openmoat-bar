#include "app/Notify.hpp"

#ifdef MOATBAR_HAS_DBUS
#include <QDBusConnection>
#include <QDBusInterface>
#include <QVariantMap>
#endif

using namespace Qt::StringLiterals;

namespace moatbar {

void notify(QSystemTrayIcon &tray, const QString &title, const QString &body, bool urgent) {
    if (tray.isVisible()) {
        tray.showMessage(title, body, urgent ? QSystemTrayIcon::Warning : QSystemTrayIcon::Information);
        return;
    }
#ifdef MOATBAR_HAS_DBUS
    QDBusInterface service(u"org.freedesktop.Notifications"_s, u"/org/freedesktop/Notifications"_s,
                           u"org.freedesktop.Notifications"_s, QDBusConnection::sessionBus());
    if (!service.isValid()) {
        return;
    }
    // urgency: 1 normal, 2 critical (stays until dismissed).
    const QVariantMap hints{{u"urgency"_s, QVariant::fromValue<uchar>(urgent ? 2 : 1)},
                            {u"desktop-entry"_s, u"dev.openmoat.moatbar"_s}};
    service.call(QDBus::NoBlock, u"Notify"_s, u"MoatBar"_s, 0U, u"dev.openmoat.moatbar"_s, title, body, QStringList{},
                 hints, -1);
#endif
}

} // namespace moatbar
