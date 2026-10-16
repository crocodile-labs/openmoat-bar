#pragma once

#include "core/Snapshot.hpp"

#include <cstdint>
#include <optional>

namespace moatbar {

/// What the tray icon shows. When several apply, the highest wins.
enum class IconState : std::uint8_t {
    Unavailable = 0, ///< moat is missing or could not be read: faded
    Quiet = 1,       ///< every agent that is set up is protected, nothing new: plain
    NewBlocks = 2,   ///< blocks since the menu was last opened: a dot
    Attention = 3,   ///< a security check needs a look: amber
    Unprotected = 4, ///< an agent that was set up is not protected now: red
};

/// Decide the icon.
/// @param snapshot the last good read, or nothing when moat is missing or unreadable.
/// @param seenUntilMs the newest event time the person has already seen in the menu.
/// @param needsAttention a security check needs a look.
[[nodiscard]] IconState decideIcon(const Snapshot *snapshot, std::optional<std::int64_t> seenUntilMs,
                                   bool needsAttention = false);

/// Words for screen readers and the tray tooltip.
[[nodiscard]] QString iconStateLabel(IconState state);

} // namespace moatbar
