#pragma once

#include "app/Preferences.hpp"
#include "app/QuickView.hpp"
#include "app/QuickViewModel.hpp"

namespace moatbar {

/// The Settings window and the first-launch Welcome window. Both are created
/// on first use and only hidden when closed.
class SettingsWindows final : public QObject {
    Q_OBJECT

public:
    /// `actions` is the Quick View's model, for opening docs.
    SettingsWindows(Preferences &preferences, QuickViewModel &actions, QObject *parent = nullptr);

    void showSettings();
    /// Show the welcome window if it hasn't been shown yet. Returns whether it was.
    bool showWelcomeOnce();

    /// Create the windows without showing them (screenshots).
    [[nodiscard]] QQuickWindow *settingsWindow();
    [[nodiscard]] QQuickWindow *welcomeWindow();
    [[nodiscard]] int warningCount() const noexcept { return m_host.warningCount(); }

    /// The welcome window's buttons.
    Q_INVOKABLE void open();
    Q_INVOKABLE void quit();

signals:
    void openRequested();
    void quitRequested();

private:
    static void bringUp(QQuickWindow *window);

    Preferences &m_preferences;
    QmlHost m_host;
    QPointer<QQuickWindow> m_settings;
    QPointer<QQuickWindow> m_welcome;
};

} // namespace moatbar
