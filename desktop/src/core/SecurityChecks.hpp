#pragma once

#include "core/Snapshot.hpp"

#include <compare>
#include <cstdint>
#include <optional>
#include <vector>

namespace moatbar {

/// One line in Security checks: what is fine, what needs a look, and the one
/// command that fixes it.
struct SecurityCheck {
    enum class Kind : std::uint8_t { Ok = 0, Info = 1, Warning = 2, Problem = 3 };

    QString id;
    Kind kind = Kind::Ok;
    QString title;
    std::optional<QString> detail;
    std::optional<QString> fix; ///< a command to copy into a terminal

    friend bool operator==(const SecurityCheck &, const SecurityCheck &) = default;
};

/// Checks built from what moat already reports (status, proxy status, version),
/// worst first. "Hook only" is info, not a warning: native Windows has no OS
/// sandbox to turn on, and the icon must not stay amber for that.
[[nodiscard]] std::vector<SecurityCheck> securityChecks(const Snapshot &snapshot);

/// Warnings and problems: the checks that turn the icon amber.
[[nodiscard]] std::vector<SecurityCheck> needingAttention(const std::vector<SecurityCheck> &checks);

} // namespace moatbar
