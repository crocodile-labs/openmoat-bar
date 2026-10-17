#pragma once

#include "app/ActivityModel.hpp"
#include "app/QuickView.hpp"
#include "app/QuickViewModel.hpp"

namespace moatbar {

/// The Activity window, opened from the Quick View, the tray menu or "Show all
/// in Activity". Created on first use; closing it only hides it.
class ActivityWindow final : public QObject {
    Q_OBJECT

public:
    /// `actions` is the Quick View's model, for copying and opening docs.
    ActivityWindow(ActivityModel &model, QuickViewModel &actions, QObject *parent = nullptr);

    /// Show it filtered to `verdict` (`deny`…, or "" for everything) and read moat.
    void show(const QString &verdict);
    /// Create the window without showing or reading (screenshots).
    bool load();

    [[nodiscard]] QQuickWindow *window() const { return m_window; }
    [[nodiscard]] int warningCount() const noexcept { return m_host.warningCount(); }

private:
    ActivityModel &m_model;
    QmlHost m_host;
    QPointer<QQuickWindow> m_window;
};

} // namespace moatbar
