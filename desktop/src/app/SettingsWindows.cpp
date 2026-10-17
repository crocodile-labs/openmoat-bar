#include "app/SettingsWindows.hpp"

using namespace Qt::StringLiterals;

namespace moatbar {

SettingsWindows::SettingsWindows(Preferences &preferences, QuickViewModel &actions, QObject *parent)
    : QObject(parent), m_preferences(preferences) {
    m_host.expose(u"prefs"_s, &m_preferences);
    m_host.expose(u"moatbar"_s, &actions);
    m_host.expose(u"welcome"_s, this);
}

QQuickWindow *SettingsWindows::settingsWindow() {
    if (!m_settings) {
        m_settings = m_host.load(u"SettingsWindow.qml"_s);
    }
    return m_settings;
}

QQuickWindow *SettingsWindows::welcomeWindow() {
    if (!m_welcome) {
        m_welcome = m_host.load(u"WelcomeWindow.qml"_s);
        if (m_welcome) {
            // However it closes, it has been seen.
            connect(m_welcome, &QWindow::visibleChanged, this, [this](bool visible) {
                if (!visible) {
                    m_preferences.setWelcomed(true);
                }
            });
        }
    }
    return m_welcome;
}

void SettingsWindows::showSettings() {
    bringUp(settingsWindow());
}

bool SettingsWindows::showWelcomeOnce() {
    if (m_preferences.welcomed()) {
        return false;
    }
    bringUp(welcomeWindow());
    return m_welcome != nullptr;
}

void SettingsWindows::open() {
    if (m_welcome) {
        m_welcome->hide();
    }
    emit openRequested();
}

void SettingsWindows::quit() {
    m_preferences.setWelcomed(true);
    emit quitRequested();
}

void SettingsWindows::bringUp(QQuickWindow *window) {
    if (window == nullptr) {
        return;
    }
    window->show();
    window->raise();
    window->requestActivate();
}

} // namespace moatbar
