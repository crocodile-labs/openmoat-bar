#pragma once

#include "app/DetailsModel.hpp"
#include "app/QuickViewModel.hpp"

#include <QElapsedTimer>
#include <QPointer>
#include <QQmlApplicationEngine>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QRect>

namespace moatbar {

/// Images for QML: `image://moatbar/logo` (the tray croc), `image://moatbar/logo-large`
/// (the full-size croc) and `image://moatbar/agent/<host>/<rrggbb>`, an agent's
/// white template icon recoloured.
class ImageProvider final : public QQuickImageProvider {
public:
    ImageProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};

/// A QML engine for one window: MoatBar's images, objects exposed to QML by
/// name, and a count of QML warnings (the screenshot tool fails on any).
class QmlHost final : public QObject {
    Q_OBJECT

public:
    explicit QmlHost(QObject *parent = nullptr);

    void expose(const QString &name, QObject *object);
    /// Load `qrc:/qml/<file>`; null, with the reason printed, if it didn't load.
    [[nodiscard]] QQuickWindow *load(const QString &file);
    [[nodiscard]] int warningCount() const noexcept { return m_warnings; }

private:
    QQmlApplicationEngine m_engine;
    int m_warnings = 0;
};

/// The Quick View: a small window with the macOS menu's content, opened from
/// the tray icon. On Windows it is a flyout beside the taskbar that closes when
/// it loses focus; on Linux a normal window, since Wayland lets the desktop
/// place windows.
class QuickView final : public QObject {
    Q_OBJECT

public:
    /// `details` backs the What you allowed, Secrets and Checks pages.
    QuickView(QuickViewModel &model, DetailsModel &details, QObject *parent = nullptr);

    /// Create the window without showing it. Returns false and prints why if
    /// the QML did not load.
    bool load();
    /// Show it, near `trayGeometry` where the desktop says where the tray is.
    void show(const QRect &trayGeometry = {});
    /// Show it on a detail page: `allowed`, `secrets` or `checks`.
    void showPage(const QString &page, const QRect &trayGeometry = {});
    [[nodiscard]] bool isVisible() const { return m_window && m_window->isVisible(); }
    void hide();
    /// It closed a moment ago. A click on the tray icon takes focus from the
    /// flyout, which closes it before the click arrives; that click must not
    /// open it again.
    [[nodiscard]] bool justClosed() const { return m_closed.isValid() && m_closed.elapsed() < 400; }

    [[nodiscard]] QQuickWindow *window() const { return m_window; }
    /// QML warnings so far (binding errors, missing properties): the screenshot tool fails on any.
    [[nodiscard]] int warningCount() const noexcept { return m_host.warningCount(); }

private:
    void place(const QRect &trayGeometry);

    QuickViewModel &m_model;
    QmlHost m_host;
    QPointer<QQuickWindow> m_window;
    QElapsedTimer m_closed;
};

} // namespace moatbar
