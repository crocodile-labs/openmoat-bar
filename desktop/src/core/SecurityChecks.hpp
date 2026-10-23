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

/// The settings file a not-protected agent's reason names when the agent's own
/// settings turn OpenMoat's hook off: `hook turned off by <file>: <what>` (openmoat
/// crates/openmoat-cli/src/protection.rs, OpenMoat 0.10.0). Nothing otherwise.
[[nodiscard]] std::optional<QString> hookTurnedOffBy(const std::optional<QString> &reason);
/// What to do about a hook an agent's own settings file turns off.
[[nodiscard]] QString turnedOffAdvice(const QString &file);
/// The command to copy for a not-protected agent: `openmoat doctor` when its own
/// settings file turns the hook off, else `openmoat`.
[[nodiscard]] QString protectionFix(const Protection &agent);

/// Warnings and problems: the checks that turn the icon amber.
[[nodiscard]] std::vector<SecurityCheck> needingAttention(const std::vector<SecurityCheck> &checks);

} // namespace moatbar
