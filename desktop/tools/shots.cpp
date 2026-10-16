// Draws the tray menu and icons from the test fixtures into PNG files, so the
// Linux and Windows menus can be looked at without either machine. Run with
// QT_QPA_PLATFORM=offscreen:
//
//     moatbar_shots OUT_DIR

#include "../tests/Fixtures.hpp"
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
    QuickView view(model);
    model.setData(protectedSnapshot, std::nullopt, now);
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
    const TrayActions actions{.open = {}, .refresh = [] {}, .about = [] {}, .quit = [] {}};

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
    return ok ? 0 : 1;
}
