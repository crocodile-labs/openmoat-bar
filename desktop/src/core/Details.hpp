#pragma once

// The detail screens, matching the macOS app's MoatBarCore (Allowed.swift,
// Secrets.swift, Doctor.swift, State/Details.swift) and openmoat's serde output:
//   allowed       crates/openmoat-cli/src/commands/allowed.rs     (OpenMoat 0.5.5+)
//   secret list   crates/openmoat-cli/src/commands/secret.rs      (OpenMoat 0.5.5+)
//   doctor        crates/openmoat-cli/src/commands/doctor/json.rs (OpenMoat 0.5.5+)

#include "core/Result.hpp"

#include <QDateTime>
#include <QString>
#include <QStringList>

#include <cstdint>
#include <functional>
#include <optional>
#include <vector>

namespace moatbar {

// MARK: - What you allowed

/// The patterns a rule lists for one kind of call.
struct RulePatterns {
    QString kind; ///< moat's name: `shell`, `fs.read`, `net`, ...
    QStringList values;

    /// Plain words for the kind: `Commands`, `Read files`, ...
    [[nodiscard]] QString label() const;
    /// `Network: docs.rs, *.docs.rs`.
    [[nodiscard]] QString line() const;

    friend bool operator==(const RulePatterns &, const RulePatterns &) = default;
};

/// One permanent rule from `moat allow --always`, `--site` or `--dir`.
struct AllowedRule {
    QString id;
    std::optional<QString> reason;
    std::vector<RulePatterns> patterns; ///< in the order `moat allowed` prints them
};

/// One `moat allow --last` answer that still applies to its session.
struct SessionGrant {
    QString host;
    QString sessionId;
    QString what; ///< in moat's words: `run "npm install"`
    std::int64_t grantedAtMs = 0;
    std::int64_t expiresAtMs = 0;
};

/// A repository whose `.moat/policy.yaml` was trusted with `moat trust`.
struct TrustedRepo {
    QString root;
    QString sha256;
};

struct AllowedReport {
    std::vector<AllowedRule> rules;
    std::vector<SessionGrant> sessionGrants;
    std::vector<TrustedRepo> trustedRepos;
};

// MARK: - Secrets

/// Where OpenMoat reads a secret's value.
struct SecretSource {
    enum class Kind : std::uint8_t { Env, File, Keychain, Unknown };
    Kind kind = Kind::Unknown;
    QString value;   ///< the variable, the path, or the keychain service
    QString account; ///< the keychain account

    /// `the variable GITHUB_TOKEN`.
    [[nodiscard]] QString label() const;
};

/// One secret OpenMoat adds to requests for one host; moat never prints the value.
struct BrokeredSecret {
    QString id;
    QString host;
    QString header;
    SecretSource source;
    bool plainHttp = false;
    /// No deny rule covers the source, so the agent could read the value there.
    /// A moat that leaves it out counts as exposed.
    bool sourceExposed = true;

    /// `api.github.com, Authorization header, from the variable GITHUB_TOKEN`.
    [[nodiscard]] QString line() const;
};

struct SecretList {
    std::vector<BrokeredSecret> secrets;
};

// MARK: - Checks

/// How a `moat doctor` line reads, from fine to worst. A status a newer moat
/// adds reads as a warning: never as fine.
enum class DoctorStatus : std::uint8_t { Ok = 0, Note = 1, Warning = 2, Problem = 3 };

[[nodiscard]] DoctorStatus doctorStatusFromWire(QStringView wire) noexcept;
[[nodiscard]] QString doctorStatusTitle(DoctorStatus status);
/// The colour role QML draws a status in: `ok`, `info`, `warn`, `bad`.
[[nodiscard]] QString doctorStatusTone(DoctorStatus status);

struct DoctorCheck {
    DoctorStatus status = DoctorStatus::Warning;
    std::optional<QString> area; ///< `policy`, `lock`, `hook`, ...
    QString name;                ///< the text output's left column; may be empty
    QString detail;

    /// The name, or the detail when the line has no name.
    [[nodiscard]] QString title() const { return name.isEmpty() ? detail : name; }
    /// The detail under the title; empty when the title already is the detail.
    [[nodiscard]] QString subtitle() const { return name.isEmpty() ? QString{} : detail; }
};

struct DoctorGroup {
    DoctorStatus status = DoctorStatus::Ok;
    std::vector<DoctorCheck> checks;
};

struct DoctorReport {
    bool healthy = false;
    int problems = 0;
    std::vector<DoctorCheck> checks;

    /// The checks by status, worst first, each in moat's order; no empty groups.
    [[nodiscard]] std::vector<DoctorGroup> groups() const;
};

// MARK: - Older moat

namespace MoatRequirement {
/// `moat allowed`, `moat secret list` and `moat doctor` with `--format json`.
[[nodiscard]] inline QString screens() { return QStringLiteral("0.5.5"); }
/// `policy_update` and `lock_drift` in `moat status --format json`.
[[nodiscard]] inline QString updateNotices() { return QStringLiteral("0.5.7"); }

/// What a screen says when moat is older than `minimum`.
[[nodiscard]] QString note(QStringView minimum);
/// The note for a status without update notices; nothing when moat sends them.
[[nodiscard]] std::optional<QString> updateNoticesNote(bool hasUpdateNotices);
} // namespace MoatRequirement

/// Whether `version` (`0.5.6`, `0.5.7-rc.1`) is at least `minimum`; nothing
/// when it can't be read. A pre-release counts as its version.
[[nodiscard]] std::optional<bool> versionAtLeast(const std::optional<QString> &version, QStringView minimum);

/// What one screen shows: moat's answer, a note that this moat is too old for
/// it, or why moat could not be read. Exactly one is set.
template <typename T>
struct Screen {
    std::optional<T> value;
    std::optional<QString> needsNewerMoat; ///< the note
    std::optional<QString> failed;         ///< the error message
};

/// The errors an older moat gives for a command or option it doesn't have.
[[nodiscard]] bool looksLikeOlderMoat(const MoatError &error);

/// Run `read` unless `version` is known to be older than `minimum`. A moat
/// that doesn't know the command or its `--format json` gives the note, not an
/// error. Name `T`: `readScreen<SecretList>(...)`.
template <typename T>
[[nodiscard]] Screen<T> readScreen(QStringView minimum, const std::optional<QString> &version,
                                   const std::function<Result<T>()> &read) {
    const auto atLeast = versionAtLeast(version, minimum);
    if (atLeast == false) {
        return {std::nullopt, MoatRequirement::note(minimum), std::nullopt};
    }
    Result<T> result = read();
    if (result) {
        return {std::move(result).value(), std::nullopt, std::nullopt};
    }
    if (atLeast != true && looksLikeOlderMoat(result.error())) {
        return {std::nullopt, MoatRequirement::note(minimum), std::nullopt};
    }
    return {std::nullopt, std::nullopt, result.error().message()};
}

/// The three detail screens from one read of moat.
struct Details {
    Screen<AllowedReport> allowed;
    Screen<SecretList> secrets;
    Screen<DoctorReport> checks;
    QDateTime takenAt;
};

// MARK: - Words

namespace DetailsText {
/// The hint `moat secret list` prints for a source no deny rule covers.
[[nodiscard]] QString exposedHint();
[[nodiscard]] QString coveredHint();
[[nodiscard]] QString plainHttpHint();
/// The command whose warning shows how to cover a source.
[[nodiscard]] QString lint();
/// `Ends in 3 h 20 min`, `Ends in 5 min`, `Ended`.
[[nodiscard]] QString endsIn(std::int64_t expiresAtMs, std::int64_t nowMs);
/// The first 12 characters of a SHA-256.
[[nodiscard]] QString shortHash(const QString &sha256);
} // namespace DetailsText

/// Words for the policy update and changed-file notices in the main view.
namespace UpdateNotices {
[[nodiscard]] QString updateTitle();
[[nodiscard]] QString updateNote();
[[nodiscard]] QString driftTitle();
[[nodiscard]] QString driftNote();
} // namespace UpdateNotices

} // namespace moatbar
