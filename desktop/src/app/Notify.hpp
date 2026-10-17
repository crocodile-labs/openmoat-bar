#pragma once

#include <QString>
#include <QSystemTrayIcon>

namespace moatbar {

/// Show a desktop notification. Through the tray icon when there is one;
/// without a tray (GNOME without its extension) through the freedesktop
/// notification service on D-Bus, which GNOME always has.
void notify(QSystemTrayIcon &tray, const QString &title, const QString &body, bool urgent);

} // namespace moatbar
