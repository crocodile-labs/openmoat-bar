#pragma once

#include "core/Models.hpp"

#include <QUrl>

#include <cstdint>
#include <optional>

namespace moatbar {

/// Plain words for OpenMoat's default rule ids. A rule from a custom policy
/// returns nothing; the reason moat gave the agent is shown instead.
namespace RuleText {
[[nodiscard]] std::optional<QString> why(QStringView rule);
}

/// Which shell a copied command will be pasted into.
enum class Shell : std::uint8_t {
    Posix,      ///< bash, zsh: Linux and macOS
    PowerShell, ///< the Windows default
};

/// The shell this build's copied commands are written for.
[[nodiscard]] constexpr Shell nativeShell() noexcept {
#ifdef Q_OS_WIN
    return Shell::PowerShell;
#else
    return Shell::Posix;
#endif
}

/// Commands MoatBar offers to copy. MoatBar never runs these; the person
/// pastes them into a terminal.
namespace CopyCommands {
[[nodiscard]] QString setUp();
[[nodiscard]] QString doctor();
[[nodiscard]] QString install(Shell shell = nativeShell());

/// `moat policy check` for this action, so the person can see the verdict and
/// rule again without running anything. Nothing for kinds it can't check.
[[nodiscard]] std::optional<QString> policyCheck(const Action &action, Shell shell = nativeShell());

/// Quote `text` as one argument: `'it'\''s'` in POSIX shells, `'it''s'` in PowerShell.
[[nodiscard]] QString quote(const QString &text, Shell shell = nativeShell());
} // namespace CopyCommands

/// Pages the menu links to.
namespace DocsLink {
[[nodiscard]] QUrl home();
[[nodiscard]] QUrl blocked();
[[nodiscard]] QUrl checkACommand();
[[nodiscard]] QUrl quickstart();
[[nodiscard]] QUrl limits();
/// A new OpenMoat issue for a wrong block. Only the rule id goes in the title.
[[nodiscard]] QUrl reportWrongBlock(const std::optional<QString> &rule);
} // namespace DocsLink

} // namespace moatbar
