#pragma once

#include "core/MoatClient.hpp"

#include <QMenu>

#include <functional>
#include <optional>

namespace moatbar {

/// What the menu can ask the app to do. Nothing here changes OpenMoat:
/// copying, opening links, refreshing, quitting.
struct TrayActions {
    std::function<void()> refresh;
    std::function<void()> about;
    std::function<void()> quit;
};

/// Builds the tray menu from one snapshot, in the same order as the macOS
/// menu: who is protected, problems, Blocked / Asked / Left to your agent /
/// Allowed (each a list of calls, each call its full story), agents, security
/// checks. Tray menus are native menus on every desktop, so the content is
/// text, icons and submenus.
class TrayMenu {
public:
    TrayMenu(const Snapshot *snapshot, std::optional<MoatError> error, TrayActions actions);

    /// Clear `menu` and fill it.
    void fill(QMenu &menu) const;

    /// Longest list a verdict submenu shows.
    static constexpr int kListLimit = 25;

private:
    void addHeader(QMenu &menu) const;
    void addProblems(QMenu &menu) const;
    void addVerdicts(QMenu &menu) const;
    void addDecision(QMenu &menu, const Event &event) const;
    void addAgents(QMenu &menu) const;
    void addChecks(QMenu &menu) const;
    void addUnavailable(QMenu &menu) const;
    void addFooter(QMenu &menu) const;

    [[nodiscard]] QString agentName(const QString &host) const;

    const Snapshot *m_snapshot;
    std::optional<MoatError> m_error;
    TrayActions m_actions;
};

} // namespace moatbar
