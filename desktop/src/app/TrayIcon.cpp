#include "app/TrayIcon.hpp"

#include <QPainter>
#include <QPainterPath>
#include <QPixmap>

#include <array>

namespace moatbar {
namespace {

const QString kLogo = QStringLiteral(":/logo-float@4x.png");

/// Tray icons are square; the croc is wide, so it sits across the middle.
QPixmap render(IconState state, int size) {
    QPixmap pixmap(size, size);
    pixmap.fill(Qt::transparent);
    QPainter painter(&pixmap);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    const QRectF tile(0, 0, size, size);
    if (state == IconState::Unprotected || state == IconState::Attention) {
        QPainterPath path;
        path.addRoundedRect(tile.adjusted(1, 1, -1, -1), size * 0.22, size * 0.22);
        painter.fillPath(path, state == IconState::Unprotected ? QColor(0xE5, 0x3E, 0x3E) : QColor(0xF0, 0x9A, 0x1A));
    }

    const QPixmap logo(kLogo);
    if (!logo.isNull()) {
        const qreal width = size * 0.94;
        const qreal height = width * logo.height() / logo.width();
        const QRectF target((size - width) / 2, (size - height) / 2, width, height);
        painter.setOpacity(state == IconState::Unavailable ? 0.4 : 1.0);
        painter.drawPixmap(target, logo, logo.rect());
        painter.setOpacity(1.0);
    }

    if (state == IconState::NewBlocks) {
        const qreal dot = size * 0.28;
        painter.setBrush(QColor(0xE5, 0x3E, 0x3E));
        painter.setPen(QPen(Qt::white, size * 0.05));
        painter.drawEllipse(QRectF(size - dot - 1, 1, dot, dot));
    }
    return pixmap;
}

} // namespace

QIcon trayIcon(IconState state) {
    QIcon icon;
    // Linux panels and the Windows tray pick the size they need.
    for (const int size : std::array{16, 22, 24, 32, 48, 64}) {
        icon.addPixmap(render(state, size));
    }
    return icon;
}

QIcon tintedIcon(const QString &resource, const QColor &color) {
    QPixmap source(resource);
    if (source.isNull()) {
        return {};
    }
    QPixmap tinted(source.size());
    tinted.fill(Qt::transparent);
    QPainter painter(&tinted);
    painter.drawPixmap(0, 0, source);
    painter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    painter.fillRect(tinted.rect(), color);
    painter.end();
    return QIcon(tinted);
}

QIcon appIcon() {
    return trayIcon(IconState::Quiet);
}

} // namespace moatbar
