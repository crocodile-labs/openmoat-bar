#pragma once

#include "core/Models.hpp"

#include <QDateTime>
#include <QTimeZone>

#include <array>
#include <cstddef>
#include <optional>
#include <vector>

namespace moatbar {

/// Calls per verdict. Indexed by `Verdict`, so every verdict has an entry.
class VerdictCounts {
public:
    [[nodiscard]] int operator[](Verdict verdict) const noexcept { return m_counts[index(verdict)]; }
    void add(Verdict verdict, int n = 1) noexcept { m_counts[index(verdict)] += n; }
    [[nodiscard]] int total() const noexcept;

    friend bool operator==(const VerdictCounts &, const VerdictCounts &) = default;

private:
    [[nodiscard]] static constexpr std::size_t index(Verdict verdict) noexcept {
        return static_cast<std::size_t>(verdict);
    }
    std::array<int, kVerdicts.size()> m_counts{};
};

/// One agent session seen in the events.
struct Session {
    QString id;
    QString host;
    std::optional<QString> cwd;
    QDateTime first;
    QDateTime last;
    VerdictCounts counts;
};

/// Everything MoatBar knows at one moment, read from moat. Menus and windows
/// are drawn from a snapshot; nothing in it is ever written back.
struct Snapshot {
    StatusReport status;
    std::vector<Event> events; ///< oldest first
    std::optional<ProxyState> proxy; ///< absent where moat has no proxy service (Windows)
    std::optional<QString> moatVersion;
    QDateTime takenAt;

    // MARK: Agents

    /// Agents installed on this machine, in moat's order.
    [[nodiscard]] std::vector<Protection> installedAgents() const;
    /// Agents that were set up but are not protected now.
    [[nodiscard]] std::vector<Protection> unprotected() const;
    [[nodiscard]] int protectedCount() const;
    [[nodiscard]] const Protection *agent(QStringView host) const;
    /// The agent's display name, or for a host `openmoat status` doesn't list
    /// (OpenMoat's proxy, `openmoat run`) its name from `HostText`.
    [[nodiscard]] QString agentName(const QString &host) const;

    // MARK: Events (`host` empty means every agent)

    [[nodiscard]] std::vector<Event> eventsFor(QStringView host = {}) const;
    [[nodiscard]] VerdictCounts counts(QStringView host = {}) const;
    /// Events with one verdict, newest first.
    [[nodiscard]] std::vector<Event> list(Verdict verdict, QStringView host = {}) const;
    /// Calls per clock hour (0…23) in `zone`, for the Today bar.
    [[nodiscard]] std::array<VerdictCounts, 24> hourly(QStringView host = {},
                                                       const QTimeZone &zone = QTimeZone::systemTimeZone()) const;
    /// Sessions, most recently active first.
    [[nodiscard]] std::vector<Session> sessions(QStringView host = {}) const;
    /// Rules that blocked or asked, most frequent first, ties by name.
    [[nodiscard]] std::vector<RuleCount> topRules(QStringView host = {}) const;
    [[nodiscard]] std::optional<QDateTime> lastCall(QStringView host) const;
    /// The newest blocked call's time, for the "new blocks" dot.
    [[nodiscard]] std::optional<std::int64_t> newestBlockMs() const;
};

/// Agents not protected now that were before. On the first read (`previous`
/// null) every unprotected agent counts, so a drop that happened while MoatBar
/// wasn't running is still reported once.
[[nodiscard]] std::vector<Protection> newlyUnprotected(const Snapshot *previous, const Snapshot &current);

/// Blocked calls in `current` that `previous` didn't have. Nothing on the first
/// read (`previous` null): blocks from before MoatBar started are not news.
[[nodiscard]] std::vector<Event> newBlocks(const Snapshot *previous, const Snapshot &current);

/// Where moat keeps its state: `$MOAT_HOME`, else `~/.moat`. MoatBar only
/// watches it; it never writes there.
[[nodiscard]] QString moatHome(const QString &moatHomeVariable, const QString &homeDirectory);

} // namespace moatbar
