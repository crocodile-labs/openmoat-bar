#include "app/QuickView.hpp"
#include "app/TrayIcon.hpp"

#include <QGuiApplication>
#include <QQmlContext>
#include <QScreen>

#include <cstdio>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

QString agentResource(QStringView host) {
    if (host == u"claude-code") {
        return u":/agent-claude@3x.png"_s;
    }
    if (host == u"codex") {
        return u":/agent-codex@3x.png"_s;
    }
    if (host == u"cursor") {
        return u":/agent-cursor@3x.png"_s;
    }
    return {};
}

} // namespace

QPixmap ImageProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const QSize want = requestedSize.isValid() ? requestedSize : QSize(32, 32);
    QPixmap pixmap;
    const QStringList parts = id.split(u'/');
    if (parts.value(0) == u"logo") {
        pixmap = appIcon().pixmap(want);
    } else if (parts.value(0) == u"agent" && parts.size() == 3) {
        const QString resource = agentResource(parts[1]);
        const QColor color(u"#"_s + parts[2]);
        if (!resource.isEmpty() && color.isValid()) {
            pixmap = tintedIcon(resource, color).pixmap(want);
        }
    }
    if (size != nullptr) {
        *size = pixmap.size();
    }
    return pixmap;
}

QuickView::QuickView(QuickViewModel &model, QObject *parent) : QObject(parent), m_model(model) {
    m_engine.addImageProvider(u"moatbar"_s, new ImageProvider); // the engine owns it
    m_engine.rootContext()->setContextProperty(u"moatbar"_s, &m_model);
}

bool QuickView::load() {
    if (m_window) {
        return true;
    }
    m_engine.setOutputWarningsToStandardError(false);
    QObject::connect(&m_engine, &QQmlEngine::warnings, this, [this](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            std::fprintf(stderr, "qml: %s\n", qPrintable(warning.toString()));
        }
        m_warnings += static_cast<int>(warnings.size());
    });
    m_engine.load(QUrl(u"qrc:/qml/QuickView.qml"_s));
    const auto roots = m_engine.rootObjects();
    m_window = roots.isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(roots.first());
    if (!m_window) {
        std::fprintf(stderr, "the Quick View did not load\n");
        return false;
    }
    connect(m_window, &QWindow::visibleChanged, this, [this](bool visible) {
        if (!visible) {
            m_closed.start();
            m_model.closed();
        }
    });
    return true;
}

void QuickView::hide() {
    if (m_window) {
        m_window->hide();
    }
}

void QuickView::show(const QRect &trayGeometry) {
    if (!load()) {
        return;
    }
    place(trayGeometry);
    m_window->show();
    m_window->raise();
    m_window->requestActivate();
}

void QuickView::place(const QRect &trayGeometry) {
#ifdef Q_OS_WIN
    // A flyout in the corner by the tray, above (or below) the taskbar.
    QScreen *screen = trayGeometry.isValid() ? QGuiApplication::screenAt(trayGeometry.center()) : nullptr;
    if (screen == nullptr) {
        screen = QGuiApplication::primaryScreen();
    }
    if (screen == nullptr) {
        return;
    }
    constexpr int kGap = 12;
    const QRect area = screen->availableGeometry();
    const QSize size = m_window->size();
    const bool trayOnTop = trayGeometry.isValid() && trayGeometry.center().y() < area.center().y();
    const bool trayOnLeft = trayGeometry.isValid() && trayGeometry.center().x() < area.center().x();
    const int x = trayOnLeft ? area.left() + kGap : area.right() - size.width() - kGap;
    const int y = trayOnTop ? area.top() + kGap : area.bottom() - size.height() - kGap;
    m_window->setPosition(x, y);
#else
    Q_UNUSED(trayGeometry)
#endif
}

} // namespace moatbar
