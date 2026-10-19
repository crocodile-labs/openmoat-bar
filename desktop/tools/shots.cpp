// Draws the tray menu and icons from the test fixtures into PNG files, so the
// Linux and Windows menus can be looked at without either machine. Run with
// QT_QPA_PLATFORM=offscreen:
//
//     moatbar_shots OUT_DIR

#include "../tests/Fixtures.hpp"
#include "app/ActivityWindow.hpp"
#include "app/DetailsModel.hpp"
#include "core/Json.hpp"
#include "app/Preferences.hpp"
#include "app/SettingsWindows.hpp"

#include <QSettings>
#include <QTemporaryDir>
#include "app/QuickView.hpp"
#include "app/QuickViewModel.hpp"
#include "app/TrayIcon.hpp"
#include "app/TrayMenu.hpp"

#include <QApplication>
#include <QDateTime>
#include <QDir>
#include <QEventLoop>
#include <QPalette>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QImage>
#include <QMenu>
#include <QPainter>
#include <QPixmap>

#include <array>
#include <cstdio>
#include <memory>
#include <optional>
#include <utility>

using namespace Qt::StringLiterals;
using namespace moatbar;

namespace {

/// Per mille of the pixels that differ from the top-left one, the background.
/// A grab that drew nothing is close to zero; text and icons are not. (Colour
/// counts don't work: Windows draws offscreen text without antialiasing.)
int drawnPerMille(const QImage &image) {
    if (image.isNull()) {
        return 0;
    }
    const QRgb background = image.pixel(0, 0);
    qint64 drawn = 0;
    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            drawn += image.pixel(x, y) != background ? 1 : 0;
        }
    }
    return static_cast<int>(drawn * 1000 / (qint64{image.width()} * image.height()));
}

bool save(const QPixmap &pixmap, const QDir &dir, const QString &name) {
    const QString path = dir.filePath(name);
    if (pixmap.isNull() || !pixmap.save(path)) {
        std::fprintf(stderr, "could not write %s\n", qPrintable(path));
        return false;
    }
    const int drawn = drawnPerMille(pixmap.toImage());
    std::printf("wrote %s (%dx%d, %d.%d%% drawn)\n", qPrintable(path), pixmap.width(), pixmap.height(), drawn / 10,
                drawn % 10);
    constexpr int kBlankPerMille = 5;
    if (drawn < kBlankPerMille) {
        std::fprintf(stderr, "%s looks blank\n", qPrintable(path));
        return false;
    }
    return true;
}

QPixmap grabMenu(QMenu &menu) {
    menu.ensurePolished();
    menu.adjustSize();
    return menu.grab();
}

/// The first submenu whose title starts with `prefix`.
QMenu *submenu(const QMenu &menu, const QString &prefix) {
    for (QAction *action : menu.actions()) {
        if (action->menu() != nullptr && action->text().startsWith(prefix)) {
            return action->menu();
        }
    }
    return nullptr;
}

/// The first submenu of `menu`, whatever its title.
QMenu *firstSubmenu(const QMenu &menu) {
    for (QAction *action : menu.actions()) {
        if (action->menu() != nullptr) {
            return action->menu();
        }
    }
    return nullptr;
}

/// The five tray icon states side by side on a light and a dark strip.
QPixmap iconStrip() {
    constexpr std::array states{IconState::Quiet, IconState::NewBlocks, IconState::Attention,
                                IconState::Unprotected, IconState::Unavailable};
    constexpr int cell = 56;
    constexpr int size = 32;
    QPixmap strip(cell * static_cast<int>(states.size()), cell * 2);
    strip.fill(Qt::transparent);
    QPainter painter(&strip);
    painter.fillRect(0, 0, strip.width(), cell, QColor(0xf2, 0xf2, 0xf2));
    painter.fillRect(0, cell, strip.width(), cell, QColor(0x24, 0x24, 0x24));
    for (std::size_t i = 0; i < states.size(); ++i) {
        const QPixmap icon = trayIcon(states[i]).pixmap(size, size);
        const int x = static_cast<int>(i) * cell + (cell - size) / 2;
        painter.drawPixmap(x, (cell - size) / 2, icon);
        painter.drawPixmap(x, cell + (cell - size) / 2, icon);
    }
    return strip;
}

std::optional<Snapshot> fixtureSnapshot(const QString &status) {
    auto runner = std::make_shared<test::StubRunner>();
    runner->stub(u"status"_s, test::fixture(status));
    runner->stub(u"show"_s, test::fixture(u"show-today"_s));
    runner->stub(u"proxy"_s, test::fixture(u"proxy-running"_s));
    runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n"));
    // A fixed "now" just after the fixture's calls, so the times read the same on every run.
    auto snapshot = MoatClient(u"moat"_s, runner).snapshot(QDateTime::fromMSecsSinceEpoch(1792061000000));
    if (!snapshot.ok()) {
        std::fprintf(stderr, "fixture %s: %s\n", qPrintable(status), qPrintable(snapshot.error().message()));
        return std::nullopt;
    }
    return std::move(snapshot).value();
}

/// The detail pages from the fixtures, as a moat 0.5.6 prints them.
Details fixtureDetails() {
    auto runner = std::make_shared<test::StubRunner>();
    runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.6 (OpenMoat)\n"));
    runner->stub(u"allowed"_s, test::fixture(u"allowed"_s));
    runner->stub(u"secret"_s, test::fixture(u"secret-list"_s));
    // The doctor lines OpenMoat 0.5.7 and later add: signing state, MCP, the audit anchor.
    runner->stub(u"doctor"_s, test::fixture(u"doctor-signed"_s));
    return MoatClient(u"moat"_s, runner).details(QDateTime::fromMSecsSinceEpoch(1792061000000));
}

/// What a moat older than 0.5.5 gets: a note per page.
Details olderMoatDetails() {
    auto runner = std::make_shared<test::StubRunner>();
    runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n"));
    return MoatClient(u"moat"_s, runner).details(QDateTime::fromMSecsSinceEpoch(1792061000000));
}

/// `snapshot` with the status that has a policy update, changed files and MCP
/// server changes to accept.
Snapshot noticesSnapshot(Snapshot snapshot) {
    const auto status = json::parseStatus(test::fixture(u"status-notices"_s));
    if (status.ok()) {
        snapshot.status.policyUpdate = status.value().policyUpdate;
        snapshot.status.lockDrift = status.value().lockDrift;
    }
    const auto mcp = json::parseStatus(test::fixture(u"status-mcp"_s));
    if (mcp.ok()) {
        snapshot.status.mcpChanges = mcp.value().mcpChanges;
    }
    return snapshot;
}

/// Let animations and layout finish.
void settle(int ms = 400) {
    QEventLoop loop;
    QTimer::singleShot(ms, &loop, &QEventLoop::quit);
    loop.exec();
}

bool call(QObject *root, const char *method, const std::optional<QString> &argument = std::nullopt) {
    const bool ok = argument ? QMetaObject::invokeMethod(root, method, Q_ARG(QVariant, QVariant(*argument)))
                             : QMetaObject::invokeMethod(root, method);
    if (!ok) {
        std::fprintf(stderr, "QuickView.qml has no %s()\n", method);
    }
    return ok;
}

QPalette darkPalette() {
    QPalette palette;
    palette.setColor(QPalette::Window, QColor(0x20, 0x21, 0x24));
    palette.setColor(QPalette::WindowText, QColor(0xe8, 0xea, 0xed));
    palette.setColor(QPalette::Base, QColor(0x17, 0x18, 0x1a));
    palette.setColor(QPalette::Text, QColor(0xe8, 0xea, 0xed));
    palette.setColor(QPalette::Button, QColor(0x2d, 0x2e, 0x31));
    palette.setColor(QPalette::ButtonText, QColor(0xe8, 0xea, 0xed));
    palette.setColor(QPalette::Highlight, QColor(0x8a, 0xb4, 0xf8));
    palette.setColor(QPalette::HighlightedText, QColor(0x20, 0x21, 0x24));
    return palette;
}

/// Every page of the Quick View, drawn by the real QML from the fixtures.
bool quickViewShots(const QDir &out, const Snapshot &protectedSnapshot, const Snapshot &unprotectedSnapshot) {
    const QDateTime now = QDateTime::fromMSecsSinceEpoch(1792061000000);
    QuickViewModel model;
    DetailsModel details;
    QuickView view(model, details);
    model.setData(protectedSnapshot, std::nullopt, now);
    details.setStatus(protectedSnapshot.status);
    details.setData(fixtureDetails(), now);
    if (!view.load()) {
        return false;
    }
    QQuickWindow *window = view.window();
    window->show();
    settle();

    bool ok = true;
    const auto shoot = [&](const QString &name) {
        settle();
        ok &= save(QPixmap::fromImage(window->grabWindow()), out, name);
    };

    shoot(u"quick-view.png"_s);

    ok &= call(window, "openList", u"deny"_s);
    shoot(u"quick-view-blocked.png"_s);

    const QVariantList blocked = model.events(u"deny"_s);
    if (blocked.isEmpty()) {
        std::fprintf(stderr, "the fixture has no blocked calls\n");
        ok = false;
    } else {
        ok &= call(window, "openDecision", blocked.first().toMap().value(u"id"_s).toString());
        shoot(u"quick-view-decision.png"_s);
    }

    ok &= call(window, "openChecks");
    shoot(u"quick-view-checks.png"_s);

    for (const QString &page : {u"allowed"_s, u"secrets"_s, u"checks"_s}) {
        ok &= call(window, "openPage", page);
        shoot(u"quick-view-%1.png"_s.arg(page == u"checks" ? u"doctor"_s : page));
    }
    // An older moat: a note on each page instead of an error.
    details.setData(olderMoatDetails(), now);
    ok &= call(window, "openPage", u"allowed"_s);
    shoot(u"quick-view-older-moat.png"_s);
    ok &= call(window, "openOverview");
    // The policy update and changed-file notices.
    model.setData(noticesSnapshot(protectedSnapshot), std::nullopt, now);
    shoot(u"quick-view-notices.png"_s);
    model.setData(protectedSnapshot, std::nullopt, now);

    ok &= call(window, "selectTab", u"claude-code"_s);
    shoot(u"quick-view-agent.png"_s);
    ok &= call(window, "selectTab", QString{});

    model.setData(unprotectedSnapshot, std::nullopt, now);
    shoot(u"quick-view-unprotected.png"_s);

    model.setData(std::nullopt, MoatError{MoatError::Kind::NotInstalled, {}, {}}, now);
    shoot(u"quick-view-moat-missing.png"_s);

    // The same overview on a dark desktop.
    const QPalette light = QGuiApplication::palette();
    QGuiApplication::setPalette(darkPalette());
    model.setData(protectedSnapshot, std::nullopt, now);
    shoot(u"quick-view-dark.png"_s);
    QGuiApplication::setPalette(light);

    window->hide();
    if (view.warningCount() > 0) {
        std::fprintf(stderr, "%d QML warnings\n", view.warningCount());
        ok = false;
    }
    return ok;
}

/// The Activity window: Blocked with the newest call open, then everything
/// filtered to one rule, then dark.
/// The Welcome and Settings windows, with settings kept in a temporary folder:
/// the tool never reads or writes the real ones.
bool settingsShots(const QDir &out) {
    QTemporaryDir scratch;
    if (!scratch.isValid()) {
        std::fprintf(stderr, "no temporary folder\n");
        return false;
    }
    Preferences preferences(std::make_unique<QSettings>(scratch.filePath(u"moatbar.ini"_s), QSettings::IniFormat),
                            scratch.filePath(u"autostart"_s), u"/usr/bin/moatbar"_s);
    preferences.setMoat(u"/usr/local/bin/moat"_s, u"0.5.3"_s);
    QuickViewModel actions;
    SettingsWindows windows(preferences, actions);

    bool ok = true;
    for (const auto &[window, name] : {std::pair{windows.welcomeWindow(), u"welcome.png"_s},
                                       std::pair{windows.settingsWindow(), u"settings.png"_s}}) {
        if (window == nullptr) {
            return false;
        }
        window->show();
        settle();
        ok &= save(QPixmap::fromImage(window->grabWindow()), out, name);
        window->hide();
    }
    if (windows.warningCount() > 0) {
        std::fprintf(stderr, "%d QML warnings in Welcome or Settings\n", windows.warningCount());
        ok = false;
    }
    return ok;
}

bool activityShots(const QDir &out, const Snapshot &snapshot) {
    QuickViewModel actions;
    ActivityModel model;
    ActivityWindow activity(model, actions);
    model.setData(snapshot.status, snapshot.events);
    if (!activity.load()) {
        return false;
    }
    QQuickWindow *window = activity.window();
    window->show();

    bool ok = true;
    const auto shoot = [&](const QString &name) {
        settle();
        ok &= save(QPixmap::fromImage(window->grabWindow()), out, name);
    };

    shoot(u"activity.png"_s);

    model.setVerdict(QString{});
    model.setRule(u"secrets-paths"_s);
    shoot(u"activity-rule.png"_s);

    const QPalette light = QGuiApplication::palette();
    QGuiApplication::setPalette(darkPalette());
    model.setRule(QString{});
    shoot(u"activity-dark.png"_s);
    QGuiApplication::setPalette(light);

    window->hide();
    if (activity.warningCount() > 0) {
        std::fprintf(stderr, "%d QML warnings in the Activity window\n", activity.warningCount());
        ok = false;
    }
    return ok;
}

} // namespace

int main(int argc, char *argv[]) {
    // Software rendering, so the Quick View draws without a GPU (CI, offscreen).
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    QQuickStyle::setStyle(u"Fusion"_s);
    QApplication app(argc, argv);
    if (argc != 2) {
        std::fprintf(stderr, "usage: moatbar_shots OUT_DIR\n");
        return 2;
    }
    const QDir out(QString::fromLocal8Bit(argv[1]));
    if (!out.mkpath(u"."_s)) {
        std::fprintf(stderr, "could not create %s\n", argv[1]);
        return 1;
    }

    const auto protectedSnapshot = fixtureSnapshot(u"status"_s);
    const auto unprotectedSnapshot = fixtureSnapshot(u"status-unprotected"_s);
    if (!protectedSnapshot || !unprotectedSnapshot) {
        return 1;
    }

    bool ok = true;
    // No "Open MoatBar": the menu as it looks where a click opens the Quick View.
    const TrayActions actions{
        .open = {},
        .activity = {},
        .settings = {},
        .details = [](const QString &) {},
        .refresh = [] {},
        .about = [] {},
        .quit = [] {}};

    QMenu menu;
    TrayMenu(&*protectedSnapshot, std::nullopt, actions).fill(menu);
    ok &= save(grabMenu(menu), out, u"menu.png"_s);
    if (QMenu *blocked = submenu(menu, u"Blocked"_s)) {
        ok &= save(grabMenu(*blocked), out, u"menu-blocked.png"_s);
        if (QMenu *decision = firstSubmenu(*blocked)) {
            ok &= save(grabMenu(*decision), out, u"menu-decision.png"_s);
        }
    } else {
        std::fprintf(stderr, "no Blocked submenu in the menu\n");
        ok = false;
    }

    QMenu unprotectedMenu;
    TrayMenu(&*unprotectedSnapshot, std::nullopt, actions).fill(unprotectedMenu);
    ok &= save(grabMenu(unprotectedMenu), out, u"menu-unprotected.png"_s);

    QMenu unavailableMenu;
    const MoatError missing{MoatError::Kind::NotInstalled, {}, {}};
    TrayMenu(nullptr, missing, actions).fill(unavailableMenu);
    ok &= save(grabMenu(unavailableMenu), out, u"menu-moat-missing.png"_s);

    ok &= save(iconStrip(), out, u"tray-icons.png"_s);

    ok &= quickViewShots(out, *protectedSnapshot, *unprotectedSnapshot);
    ok &= activityShots(out, *protectedSnapshot);
    ok &= settingsShots(out);
    return ok ? 0 : 1;
}
