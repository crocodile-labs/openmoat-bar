#pragma once

#include "app/QuickViewModel.hpp"

#include <QElapsedTimer>
#include <QPointer>
#include <QQmlApplicationEngine>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QRect>

namespace moatbar {

/// Images for QML: `image://moatbar/logo` and `image://moatbar/agent/<host>/<rrggbb>`,
/// an agent's white template icon recoloured.
class ImageProvider final : public QQuickImageProvider {
public:
    ImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};

/// The Quick View: a small window with the macOS menu's content, opened from
/// the tray icon. On Windows it is a flyout beside the taskbar that closes when
/// it loses focus; on Linux a normal window, since Wayland lets the desktop
/// place windows.
class QuickView final : public QObject {
    Q_OBJECT

public:
    explicit QuickView(QuickViewModel &model, QObject *parent = nullptr);

    /// Create the window without showing it. Returns false and prints why if
    /// the QML did not load.
    bool load();
    /// Show it, near `trayGeometry` where the desktop says where the tray is.
    void show(const QRect &trayGeometry = {});
    [[nodiscard]] bool isVisible() const { return m_window && m_window->isVisible(); }
    void hide();
    /// It closed a moment ago. A click on the tray icon takes focus from the
    /// flyout, which closes it before the click arrives; that click must not
    /// open it again.
    [[nodiscard]] bool justClosed() const { return m_closed.isValid() && m_closed.elapsed() < 400; }

    [[nodiscard]] QQuickWindow *window() const { return m_window; }
    /// QML warnings so far (binding errors, missing properties): the screenshot tool fails on any.
    [[nodiscard]] int warningCount() const noexcept { return m_warnings; }

private:
    void place(const QRect &trayGeometry);

    QuickViewModel &m_model;
    QQmlApplicationEngine m_engine;
    QPointer<QQuickWindow> m_window;
    QElapsedTimer m_closed;
    int m_warnings = 0;
};

} // namespace moatbar
