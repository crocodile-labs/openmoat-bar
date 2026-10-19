#pragma once

#include "core/Models.hpp"

#include <QUrl>

#include <cstdint>
#include <optional>

namespace moatbar {

/// Plain words for OpenMoat's default rule ids and the ones its guard adds, the
/// same table as the macOS app's RuleText.swift. A rule from a custom policy
/// returns nothing; the reason moat gave the agent is shown instead.
namespace RuleText {
/// One sentence on why the rule exists. `pack:<name>:<id>` and `repo:<id>`
/// rules name where they come from.
[[nodiscard]] std::optional<QString> why(QStringView rule);
/// The rule id moat adds after the deciding rule to the first call of a session
/// decided while a pinned settings file differs in ways that change no decision.
[[nodiscard]] inline QString settingsDrift() { return QStringLiteral("settings-drift"); }
/// The note for such a call; nothing when moat added none, or when it is the
/// only rule (then `why` already says it).
[[nodiscard]] std::optional<QString> driftNote(const QStringList &rules);
} // namespace RuleText

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
/// Show the newer default policy's changes and ask before applying them.
[[nodiscard]] QString policyUpgrade();
/// Show what changed in one MCP server (or, without a name, every one) and ask
/// before accepting it. Only a person in a terminal can run it.
[[nodiscard]] QString mcpAccept(const std::optional<QString> &server, Shell shell = nativeShell());
/// Take back a permanent rule, as `moat allowed` prints it.
[[nodiscard]] QString removeRule(const QString &id, Shell shell = nativeShell());
/// Stop trusting a repository's policy, as `moat allowed` prints it.
[[nodiscard]] QString revokeTrust(const QString &root, Shell shell = nativeShell());
/// `text` as is when the shell would leave it alone, else `quote(text)`.
[[nodiscard]] QString quoteIfNeeded(const QString &text, Shell shell = nativeShell());

/// `moat policy check` for this action, so the person can see the verdict and
/// rule again without running anything. Nothing for kinds it can't check.
[[nodiscard]] std::optional<QString> policyCheck(const Action &action, Shell shell = nativeShell());

/// Quote `text` as one argument: `'it'\''s'` in POSIX shells, `'it''s'` in PowerShell.
[[nodiscard]] QString quote(const QString &text, Shell shell = nativeShell());
} // namespace CopyCommands

/// Words for the MCP server changes in the main view, from `mcp_changes` in
/// `moat status --format json` (OpenMoat 0.5.7 and later).
namespace McpNotices {
[[nodiscard]] QString title();
[[nodiscard]] QString note();
/// The server a line names: ``MCP server `gh` in /path changed`` gives `gh`.
/// Nothing for a line about a file moat could not read.
[[nodiscard]] std::optional<QString> server(const QString &line);
/// The servers the lines name, each once, in moat's order.
[[nodiscard]] QStringList servers(const QStringList &lines);
/// `moat mcp accept <server>` per server, or plain `moat mcp accept` when no
/// line names one.
[[nodiscard]] QStringList acceptCommands(const QStringList &lines, Shell shell = nativeShell());
} // namespace McpNotices

/// Pages the menu links to.
namespace DocsLink {
[[nodiscard]] QUrl home();
[[nodiscard]] QUrl blocked();
[[nodiscard]] QUrl checkACommand();
[[nodiscard]] QUrl quickstart();
[[nodiscard]] QUrl limits();
[[nodiscard]] QUrl turnOff();
/// A new OpenMoat issue for a wrong block. Only the rule id goes in the title.
[[nodiscard]] QUrl reportWrongBlock(const std::optional<QString> &rule);
} // namespace DocsLink

} // namespace moatbar
