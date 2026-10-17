#include "core/Snapshot.hpp"

#include <QDir>
#include <QSet>

#include <algorithm>
#include <functional>
#include <iterator>
#include <limits>
#include <map>
#include <numeric>
#include <ranges>

namespace moatbar {
namespace {

bool matches(const Event &event, QStringView host) {
    return host.isEmpty() || event.host == host;
}

} // namespace

int VerdictCounts::total() const noexcept {
    return std::accumulate(m_counts.begin(), m_counts.end(), 0);
}

std::vector<Protection> Snapshot::installedAgents() const {
    std::vector<Protection> out;
    std::ranges::copy_if(status.agents, std::back_inserter(out),
                         [](const Protection &agent) { return agent.level != Level::NotFound; });
    return out;
}

std::vector<Protection> Snapshot::unprotected() const {
    std::vector<Protection> out;
    std::ranges::copy_if(status.agents, std::back_inserter(out),
                         [](const Protection &agent) { return agent.level == Level::NotProtected; });
    return out;
}

int Snapshot::protectedCount() const {
    return static_cast<int>(
        std::ranges::count_if(status.agents, [](const Protection &agent) { return isHooked(agent.level); }));
}

const Protection *Snapshot::agent(QStringView host) const {
    const auto it = std::ranges::find_if(status.agents, [host](const Protection &agent) { return agent.host == host; });
    return it == status.agents.end() ? nullptr : &*it;
}

std::vector<Event> Snapshot::eventsFor(QStringView host) const {
    std::vector<Event> out;
    std::ranges::copy_if(events, std::back_inserter(out), [host](const Event &event) { return matches(event, host); });
    return out;
}

VerdictCounts Snapshot::counts(QStringView host) const {
    VerdictCounts out;
    for (const Event &event : events) {
        if (matches(event, host)) {
            out.add(event.verdict);
        }
    }
    return out;
}

std::vector<Event> Snapshot::list(Verdict verdict, QStringView host) const {
    std::vector<Event> out;
    for (const Event &event : std::ranges::reverse_view(events)) {
        if (event.verdict == verdict && matches(event, host)) {
            out.push_back(event);
        }
    }
    return out;
}

std::array<VerdictCounts, 24> Snapshot::hourly(QStringView host, const QTimeZone &zone) const {
    std::array<VerdictCounts, 24> hours{};
    for (const Event &event : events) {
        if (matches(event, host)) {
            const int hour = event.time().toTimeZone(zone).time().hour();
            hours.at(static_cast<std::size_t>(hour)).add(event.verdict);
        }
    }
    return hours;
}

std::vector<Session> Snapshot::sessions(QStringView host) const {
    std::map<QString, Session> byId;
    for (const Event &event : events) {
        if (!matches(event, host)) {
            continue;
        }
        auto [it, inserted] = byId.try_emplace(event.sessionId);
        Session &session = it->second;
        if (inserted) {
            session.id = event.sessionId;
            session.host = event.host;
            session.first = event.time();
            session.last = event.time();
        }
        session.first = std::min(session.first, event.time());
        session.last = std::max(session.last, event.time());
        session.counts.add(event.verdict);
        if (!session.cwd) {
            session.cwd = event.cwd;
        }
    }
    std::vector<Session> out;
    out.reserve(byId.size());
    for (auto &entry : byId) {
        out.push_back(std::move(entry.second));
    }
    std::ranges::sort(out, [](const Session &a, const Session &b) {
        return a.last != b.last ? a.last > b.last : a.id < b.id;
    });
    return out;
}

std::vector<RuleCount> Snapshot::topRules(QStringView host) const {
    std::map<QString, int> counts;
    for (const Event &event : events) {
        if ((event.verdict == Verdict::Deny || event.verdict == Verdict::Ask) && matches(event, host)) {
            if (const auto rule = event.rule()) {
                ++counts[*rule];
            }
        }
    }
    std::vector<RuleCount> out;
    out.reserve(counts.size());
    for (const auto &[rule, count] : counts) {
        out.push_back(RuleCount{rule, count});
    }
    // std::map already orders by name, so a stable sort by count keeps ties by name.
    std::ranges::stable_sort(out, std::ranges::greater{}, &RuleCount::count);
    return out;
}

std::optional<QDateTime> Snapshot::lastCall(QStringView host) const {
    for (const Event &event : std::ranges::reverse_view(events)) {
        if (event.host == host) {
            return event.time();
        }
    }
    return std::nullopt;
}

std::vector<Protection> newlyUnprotected(const Snapshot *previous, const Snapshot &current) {
    std::vector<Protection> out;
    for (const Protection &agent : current.unprotected()) {
        const Protection *before = previous ? previous->agent(agent.host) : nullptr;
        if (before == nullptr || before->level != Level::NotProtected) {
            out.push_back(agent);
        }
    }
    return out;
}

std::vector<Event> newBlocks(const Snapshot *previous, const Snapshot &current) {
    if (previous == nullptr) {
        return {};
    }
    // Ids seen before, and nothing older than the newest call seen before (a
    // new day's read starts over with fresh ids).
    const std::int64_t seen = previous->events.empty() ? std::numeric_limits<std::int64_t>::min()
                                                       : previous->events.back().tsMs;
    QSet<QString> known;
    for (const Event &event : previous->events) {
        known.insert(event.id);
    }
    std::vector<Event> out;
    for (const Event &event : current.events) {
        if (event.verdict == Verdict::Deny && event.tsMs >= seen && !known.contains(event.id)) {
            out.push_back(event);
        }
    }
    return out;
}

QString moatHome(const QString &moatHomeVariable, const QString &homeDirectory) {
    if (!moatHomeVariable.isEmpty()) {
        return QDir::cleanPath(moatHomeVariable);
    }
    return QDir(homeDirectory).filePath(QStringLiteral(".moat"));
}

std::optional<std::int64_t> Snapshot::newestBlockMs() const {
    for (const Event &event : std::ranges::reverse_view(events)) {
        if (event.verdict == Verdict::Deny) {
            return event.tsMs;
        }
    }
    return std::nullopt;
}

} // namespace moatbar
