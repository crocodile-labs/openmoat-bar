#include "core/ActivityFilter.hpp"

namespace moatbar {

std::vector<Event> ActivityFilter::apply(const std::vector<Event> &events) const {
    std::vector<Event> out;
    for (auto it = events.rbegin(); it != events.rend(); ++it) {
        const bool matches = (host.isEmpty() || it->host == host) && (!verdict || it->verdict == *verdict) &&
                             (rule.isEmpty() || it->rules.contains(rule));
        if (matches) {
            out.push_back(*it);
        }
    }
    return out;
}

} // namespace moatbar
