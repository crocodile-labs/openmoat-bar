#include "app/QuickView.hpp"
#include "app/TrayIcon.hpp"

#include <QGuiApplication>
#include <QImage>
#include <QPainter>
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
    if (host == u"openclaw") {
        return u":/agent-openclaw@3x.png"_s;
    }
    if (host == u"copilot-cli") {
        return u":/agent-copilot@3x.png"_s;
    }
    if (host == u"pi") {
        return u":/agent-pi@3x.png"_s;
    }
    if (host == u"gemini-cli") {
        return u":/agent-gemini@3x.png"_s;
    }
    return {};
}

/// The image without its transparent border, scaled to fit a `size` square.
/// The agent icons and the croc have wide transparent margins, which at 16 px
/// leave a speck.
QPixmap fitted(QPixmap source, const QSize &size) {
    // Pixels, not points: Qt reads "@4x" in a file name as a device pixel
    // ratio, which would draw the croc at a quarter of the size asked for.
    source.setDevicePixelRatio(1.0);
    const QImage image = source.toImage().convertToFormat(QImage::Format_ARGB32);
    QRect used;
    for (int y = 0; y < image.height(); ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) > 8) {
                used |= QRect(x, y, 1, 1);
            }
        }
    }
    if (used.isEmpty()) {
        return {};
    }
    const QPixmap cropped = source.copy(used).scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QPixmap out(size);
    out.fill(Qt::transparent);
    QPainter painter(&out);
    painter.drawPixmap((size.width() - cropped.width()) / 2, (size.height() - cropped.height()) / 2, cropped);
    return out;
}

} // namespace

QPixmap ImageProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) {
    const QSize want = requestedSize.isValid() ? requestedSize : QSize(32, 32);
    QPixmap pixmap;
    const QStringList parts = id.split(u'/');
    if (parts.value(0) == u"logo") {
        pixmap = fitted(appIcon().pixmap(256), want);
    } else if (parts.value(0) == u"logo-large") {
        // The full-size croc, for the welcome window.
        pixmap = fitted(QPixmap(u":/logo-float@4x.png"_s), want);
    } else if (parts.value(0) == u"agent" && parts.size() == 3) {
        const QString resource = agentResource(parts[1]);
        const QColor color(u"#"_s + parts[2]);
        if (!resource.isEmpty() && color.isValid()) {
            pixmap = fitted(tintedIcon(resource, color).pixmap(256), want);
        }
    }
    if (size != nullptr) {
        *size = pixmap.size();
    }
    return pixmap;
}

QmlHost::QmlHost(QObject *parent) : QObject(parent) {
    m_engine.addImageProvider(u"moatbar"_s, new ImageProvider); // the engine owns it
    m_engine.setOutputWarningsToStandardError(false);
    connect(&m_engine, &QQmlEngine::warnings, this, [this](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings) {
            std::fprintf(stderr, "qml: %s\n", qPrintable(warning.toString()));
        }
        m_warnings += static_cast<int>(warnings.size());
    });
}

void QmlHost::expose(const QString &name, QObject *object) {
    m_engine.rootContext()->setContextProperty(name, object);
}

QQuickWindow *QmlHost::load(const QString &file) {
    m_engine.load(QUrl(QString(u"qrc:/qml/"_s + file)));
    const auto roots = m_engine.rootObjects();
    auto *window = roots.isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(roots.last());
    if (window == nullptr) {
        std::fprintf(stderr, "%s did not load\n", qPrintable(file));
    }
    return window;
}

QuickView::QuickView(QuickViewModel &model, DetailsModel &details, QObject *parent) : QObject(parent), m_model(model) {
    m_host.expose(u"moatbar"_s, &m_model);
    m_host.expose(u"details"_s, &details);
}

void QuickView::showPage(const QString &page, const QRect &trayGeometry) {
    show(trayGeometry);
    if (m_window) {
        QMetaObject::invokeMethod(m_window, "openPage", Q_ARG(QVariant, QVariant(page)));
    }
}

bool QuickView::load() {
    if (m_window) {
        return true;
    }
    m_window = m_host.load(u"QuickView.qml"_s);
    if (!m_window) {
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
