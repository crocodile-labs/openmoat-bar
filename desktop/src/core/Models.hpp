#pragma once

// The shapes of moat's `--format json` output, matching the macOS app's
// MoatBarCore and openmoat's serde output:
//   status        crates/openmoat-cli/src/protection.rs
//   show          crates/openmoat-audit/src/store.rs   (Event)
//   report        crates/openmoat-audit/src/query.rs   (Summary)
//   proxy status  crates/openmoat-cli/src/commands/service.rs

#include <QDateTime>
#include <QJsonObject>
#include <QString>
#include <QStringList>

#include <array>
#include <cstdint>
#include <map>
#include <optional>
#include <vector>

namespace moatbar {

// MARK: - Protection

/// How much of the policy is enforced for one agent.
enum class Level : std::uint8_t {
    HookAndOsSandbox,
    HookOnly,
    NotProtected,
    NotSetUp,
    NotFound,
    Unknown, ///< A level a newer moat added. Never shown as protected.
};

[[nodiscard]] Level levelFromWire(QStringView wire) noexcept;
[[nodiscard]] QString levelLabel(Level level);
[[nodiscard]] constexpr bool isHooked(Level level) noexcept {
    return level == Level::HookAndOsSandbox || level == Level::HookOnly;
}

/// One agent's protection: `agents[]` in `openmoat status --format json`.
struct Protection {
    QString host; ///< `claude-code`, `codex`, `cursor`
    QString name; ///< `Claude Code`
    Level level = Level::Unknown;
    std::optional<QString> reason;
    QString gaps;
};

/// The whole `openmoat status --format json` document (commands/status.rs).
struct StatusReport {
    std::vector<Protection> agents;
    /// `3 changes from the OpenMoat 0.5.7 default` when `openmoat policy upgrade` has changes.
    std::optional<QString> policyUpdate;
    /// Pinned files that changed since: `… was modified`, `… is missing`.
    QStringList lockDrift;
    /// Whether moat sent `policy_update` and `lock_drift` at all (OpenMoat 0.5.7+).
    bool hasUpdateNotices = true;
    /// MCP server definitions and held tools that wait for `openmoat mcp accept`, one
    /// line each (``MCP server `gh` in /path changed``). Empty when nothing waits,
    /// and from a moat that doesn't send it (before 0.5.7).
    QStringList mcpChanges;
    /// Project settings files that could switch OpenMoat off or run a program, one
    /// line each (``/path/.claude/settings.json: `hooks` adds hooks that run commands.
    /// A Claude Code session started here loads it; …``). Empty when there are none,
    /// and from a moat that doesn't send it (before 0.8.0).
    QStringList projectSettings;
};

// MARK: - Verdicts and actions

enum class Verdict : std::uint8_t { Deny, Ask, Deferred, Allow };

/// Every verdict, in the order the menu lists them.
inline constexpr std::array kVerdicts{Verdict::Deny, Verdict::Ask, Verdict::Deferred, Verdict::Allow};

/// An unknown verdict from a newer moat counts as left to the agent: never as
/// allowed or blocked.
[[nodiscard]] Verdict verdictFromWire(QStringView wire) noexcept;
[[nodiscard]] QString verdictTitle(Verdict verdict);
[[nodiscard]] QString verdictSubtitle(Verdict verdict);

/// The call an agent made, as moat stores it (already redacted). moat writes it
/// as an externally tagged enum: `{"shell": {"command": "ls"}}`.
struct Action {
    enum class Kind : std::uint8_t {
        Shell, ForeignShell, FsRead, FsWrite, Net, Fetch, WebSearch, UnknownTool, Patch, ReadFiles, McpTool, Other,
    };

    Kind kind = Kind::Other;
    QString target;      ///< command, path, url, query, tool or MCP name
    QString qualifier;   ///< the foreign shell's name, the unknown tool's host
    QStringList targets; ///< files a patch writes or a call reads
    QString wireKind;    ///< the tag as moat wrote it, for kinds MoatBar doesn't know

    /// One line a person can read.
    [[nodiscard]] QString display() const;
    /// The command line, for actions `openmoat policy check` can check again.
    [[nodiscard]] std::optional<QString> shellCommand() const;
};

/// One audit event. `openmoat show --format json` prints an array of these.
struct Event {
    QString id; ///< hex row id; older moat builds wrote an integer
    std::int64_t tsMs = 0;
    QString host;
    QString sessionId;
    std::optional<QString> cwd;
    QString tool;
    std::optional<Action> action;
    Verdict verdict = Verdict::Deferred;
    QStringList rules;
    QStringList reasons;
    /// The event exactly as moat printed it (moat has already redacted it),
    /// so an export keeps every field, including ones MoatBar doesn't read.
    QJsonObject raw;

    [[nodiscard]] QDateTime time() const { return QDateTime::fromMSecsSinceEpoch(tsMs); }
    [[nodiscard]] QString display() const { return action ? action->display() : tool; }
    [[nodiscard]] std::optional<QString> rule() const;
    [[nodiscard]] std::optional<QString> reason() const;
};

// MARK: - Report and proxy

struct RuleCount {
    QString rule;
    int count = 0;
    friend bool operator==(const RuleCount &, const RuleCount &) = default;
};

/// Totals for a window: `openmoat report --since <window> --format json`.
struct Summary {
    std::int64_t sinceMs = 0;
    int total = 0;
    int allowed = 0;
    int deferred = 0;
    int asked = 0;
    int denied = 0;
    int sessions = 0;
    std::map<QString, int> byHost;
    std::vector<RuleCount> topRules;
    int activeHours = 0;
};

/// The proxy service's state (`openmoat proxy status`, macOS and Linux only).
struct ProxyState {
    enum class Kind : std::uint8_t { NotInstalled, Stopped, Running, DriftBlocked, Crashlooping, Unknown };
    Kind kind = Kind::Unknown;
    QString details;

    [[nodiscard]] bool running() const noexcept { return kind == Kind::Running; }
    [[nodiscard]] QString label() const;
};

/// A time window moat understands in `--since`.
enum class TimeWindow : std::uint8_t { Today, SevenDays, ThirtyDays };
[[nodiscard]] QString timeWindowWire(TimeWindow window);
[[nodiscard]] QString timeWindowTitle(TimeWindow window);

} // namespace moatbar
