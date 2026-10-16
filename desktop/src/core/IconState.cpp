#include "core/IconState.hpp"

#include <limits>

using namespace Qt::StringLiterals;

namespace moatbar {

IconState decideIcon(const Snapshot *snapshot, std::optional<std::int64_t> seenUntilMs, bool needsAttention) {
    if (snapshot == nullptr) {
        return IconState::Unavailable;
    }
    if (!snapshot->unprotected().empty()) {
        return IconState::Unprotected;
    }
    if (needsAttention) {
        return IconState::Attention;
    }
    const auto newest = snapshot->newestBlockMs();
    if (newest && *newest > seenUntilMs.value_or(std::numeric_limits<std::int64_t>::min())) {
        return IconState::NewBlocks;
    }
    return IconState::Quiet;
}

QString iconStateLabel(IconState state) {
    switch (state) {
    case IconState::Unavailable: return u"MoatBar: OpenMoat not found"_s;
    case IconState::Quiet: return u"MoatBar: all protected"_s;
    case IconState::NewBlocks: return u"MoatBar: new blocked calls"_s;
    case IconState::Attention: return u"MoatBar: a security check needs a look"_s;
    case IconState::Unprotected: return u"MoatBar: an agent is not protected"_s;
    }
    return {};
}

} // namespace moatbar
