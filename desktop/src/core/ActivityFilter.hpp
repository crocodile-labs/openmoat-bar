#pragma once

#include "core/Models.hpp"

#include <optional>
#include <vector>

namespace moatbar {

/// What the Activity window shows: one agent or all, one verdict or all,
/// optionally one rule. The same filter as the macOS app's.
struct ActivityFilter {
    QString host;                            ///< empty: every agent
    std::optional<Verdict> verdict = Verdict::Deny; ///< nothing: every verdict
    QString rule;                            ///< empty: every rule

    /// Matching events, newest first. `events` is oldest first, as moat prints them.
    [[nodiscard]] std::vector<Event> apply(const std::vector<Event> &events) const;

    friend bool operator==(const ActivityFilter &, const ActivityFilter &) = default;
};

} // namespace moatbar
