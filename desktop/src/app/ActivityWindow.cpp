#include "app/ActivityWindow.hpp"

using namespace Qt::StringLiterals;

namespace moatbar {

ActivityWindow::ActivityWindow(ActivityModel &model, QuickViewModel &actions, QObject *parent)
    : QObject(parent), m_model(model) {
    m_host.expose(u"activity"_s, &m_model);
    m_host.expose(u"moatbar"_s, &actions);
}

bool ActivityWindow::load() {
    if (!m_window) {
        m_window = m_host.load(u"ActivityWindow.qml"_s);
    }
    return m_window != nullptr;
}

void ActivityWindow::show(const QString &verdict) {
    if (!load()) {
        return;
    }
    m_model.setVerdict(verdict);
    m_model.load();
    m_window->show();
    m_window->raise();
    m_window->requestActivate();
}

} // namespace moatbar
