#include "app/SnapshotStore.hpp"
#include "app/TrayController.hpp"
#include "app/TrayIcon.hpp"

#include <QApplication>
#include <QMessageBox>
#include <QQuickStyle>
#include <QSystemTrayIcon>

using namespace Qt::StringLiterals;

int main(int argc, char *argv[]) {
    // Fusion draws the same on every desktop and follows its palette, light or dark.
    QQuickStyle::setStyle(u"Fusion"_s);
    QApplication app(argc, argv);
    QApplication::setApplicationName(u"MoatBar"_s);
    QApplication::setApplicationDisplayName(u"MoatBar"_s);
    QApplication::setApplicationVersion(QStringLiteral(MOATBAR_VERSION));
    QApplication::setOrganizationName(u"Crocodile Labs"_s);
    QApplication::setOrganizationDomain(u"openmoat.dev"_s);
    QApplication::setWindowIcon(moatbar::appIcon());
    // A tray app: closing a window (About) must not quit it.
    QApplication::setQuitOnLastWindowClosed(false);

    if (!QSystemTrayIcon::isSystemTrayAvailable()) {
        // GNOME without the AppIndicator extension has no tray. A window view
        // for that case comes next; until then, say so instead of running unseen.
        QMessageBox::warning(nullptr, u"MoatBar"_s,
                             u"This desktop has no system tray. On GNOME, install the "
                             u"“AppIndicator and KStatusNotifierItem Support” extension."_s);
        return 1;
    }

    moatbar::SnapshotStore store;
    moatbar::TrayController tray(store);
    tray.show();
    store.start();
    return QApplication::exec();
}
