#include "app/SingleInstance.hpp"
#include "app/SnapshotStore.hpp"
#include "app/TrayController.hpp"
#include "app/TrayIcon.hpp"

#include <QApplication>
#include <QCommandLineParser>
#include <QQuickStyle>

#include <cstdio>

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
    QApplication::setDesktopFileName(u"dev.openmoat.moatbar"_s);
    QApplication::setWindowIcon(moatbar::appIcon());
    // A tray app: closing a window must not quit it.
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(u"See what OpenMoat does for your coding agents. Read-only."_s);
    parser.addHelpOption();
    parser.addVersionOption();
    const QCommandLineOption background(u"background"_s, u"Start without opening a window (for start at login)."_s);
    const QCommandLineOption activity(u"activity"_s, u"Open the Activity window."_s);
    const QCommandLineOption settings(u"settings"_s, u"Open Settings."_s);
    const QCommandLineOption quit(u"quit"_s, u"Quit the MoatBar that is running."_s);
    parser.addOptions({background, activity, settings, quit});
    parser.process(app);

    // What this start asks for. A plain start (the app menu, the Start menu)
    // opens the Quick View; --background opens nothing.
    QString request = u"show"_s;
    if (parser.isSet(quit)) {
        request = u"quit"_s;
    } else if (parser.isSet(activity)) {
        request = u"activity"_s;
    } else if (parser.isSet(settings)) {
        request = u"settings"_s;
    } else if (parser.isSet(background)) {
        request.clear();
    }

    // One MoatBar per user: hand the request to the one that is running.
    moatbar::SingleInstance instance;
    if (instance.sendToRunning(request.isEmpty() ? u"ping"_s : request)) {
        return 0;
    }
    if (request == u"quit") {
        return 0; // nothing running
    }
    if (!instance.listen()) {
        std::fprintf(stderr, "moatbar: another MoatBar may be starting; continuing without the single-instance socket\n");
    }

    moatbar::SnapshotStore store;
    moatbar::TrayController tray(store);
    QObject::connect(&instance, &moatbar::SingleInstance::requested, &tray, &moatbar::TrayController::handleRequest);
    tray.show();
    store.start();
    // The first launch shows the welcome window instead.
    if (!tray.welcomeOnFirstLaunch() && !request.isEmpty()) {
        tray.handleRequest(request);
    }
    return QApplication::exec();
}
