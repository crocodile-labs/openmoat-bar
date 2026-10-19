#include "core/Details.hpp"

#include <algorithm>
#include <array>
#include <iterator>

using namespace Qt::StringLiterals;

namespace moatbar {

// MARK: - What you allowed

QString RulePatterns::label() const {
    if (kind == u"shell") {
        return u"Commands"_s;
    }
    if (kind == u"fs.read") {
        return u"Read files"_s;
    }
    if (kind == u"fs.write") {
        return u"Write files"_s;
    }
    if (kind == u"net") {
        return u"Network"_s;
    }
    if (kind == u"fetch") {
        return u"Fetch pages"_s;
    }
    if (kind == u"env.read") {
        return u"Read variables"_s;
    }
    if (kind == u"env.set") {
        return u"Set variables"_s;
    }
    if (kind == u"mcp") {
        return u"MCP tools"_s;
    }
    return kind;
}

QString RulePatterns::line() const {
    return label() + u": "_s + values.join(u", "_s);
}

// MARK: - Secrets

QString SecretSource::label() const {
    switch (kind) {
    case Kind::Env: return u"the variable %1"_s.arg(value);
    case Kind::File: return u"the file %1"_s.arg(value);
    case Kind::Keychain: return u"the keychain item %1 (%2)"_s.arg(value, account);
    case Kind::Unknown: return u"a source this MoatBar doesn't know"_s;
    }
    return u"a source this MoatBar doesn't know"_s;
}

QString BrokeredSecret::line() const {
    return u"%1, %2 header, from %3"_s.arg(host, header, source.label());
}

// MARK: - Checks

DoctorStatus doctorStatusFromWire(QStringView wire) noexcept {
    if (wire == u"ok") {
        return DoctorStatus::Ok;
    }
    if (wire == u"note") {
        return DoctorStatus::Note;
    }
    if (wire == u"problem") {
        return DoctorStatus::Problem;
    }
    return DoctorStatus::Warning; // "warning", and anything a newer moat adds
}

QString doctorStatusTitle(DoctorStatus status) {
    switch (status) {
    case DoctorStatus::Problem: return u"Problems"_s;
    case DoctorStatus::Warning: return u"Needs a look"_s;
    case DoctorStatus::Note: return u"Notes"_s;
    case DoctorStatus::Ok: return u"Fine"_s;
    }
    return u"Needs a look"_s;
}

QString doctorStatusTone(DoctorStatus status) {
    switch (status) {
    case DoctorStatus::Problem: return u"bad"_s;
    case DoctorStatus::Warning: return u"warn"_s;
    case DoctorStatus::Note: return u"info"_s;
    case DoctorStatus::Ok: return u"ok"_s;
    }
    return u"warn"_s;
}

std::vector<DoctorGroup> DoctorReport::groups() const {
    constexpr std::array order{DoctorStatus::Problem, DoctorStatus::Warning, DoctorStatus::Note, DoctorStatus::Ok};
    std::vector<DoctorGroup> out;
    for (const DoctorStatus status : order) {
        DoctorGroup group{status, {}};
        std::ranges::copy_if(checks, std::back_inserter(group.checks),
                             [status](const DoctorCheck &check) { return check.status == status; });
        if (!group.checks.empty()) {
            out.push_back(std::move(group));
        }
    }
    return out;
}

// MARK: - Older moat

QString MoatRequirement::note(QStringView minimum) {
    return u"This needs OpenMoat %1 or later. Update moat to see it here."_s.arg(minimum);
}

std::optional<QString> MoatRequirement::updateNoticesNote(bool hasUpdateNotices) {
    if (hasUpdateNotices) {
        return std::nullopt;
    }
    return u"Policy update and changed-file notices need OpenMoat %1 or later."_s.arg(updateNotices());
}

namespace {

std::optional<std::array<int, 3>> versionParts(QStringView text) {
    const QStringView core = text.trimmed().split(u'-').value(0);
    const auto pieces = core.split(u'.');
    if (pieces.size() != 3) {
        return std::nullopt;
    }
    std::array<int, 3> out{};
    for (std::size_t i = 0; i < out.size(); ++i) {
        bool ok = false;
        out[i] = pieces[static_cast<qsizetype>(i)].toInt(&ok);
        if (!ok) {
            return std::nullopt;
        }
    }
    return out;
}

} // namespace

std::optional<bool> versionAtLeast(const std::optional<QString> &version, QStringView minimum) {
    if (!version) {
        return std::nullopt;
    }
    const auto have = versionParts(*version);
    const auto need = versionParts(minimum);
    if (!have || !need) {
        return std::nullopt;
    }
    return *have >= *need;
}

bool looksLikeOlderMoat(const MoatError &error) {
    switch (error.kind) {
    case MoatError::Kind::Unreadable: return true;
    case MoatError::Kind::Failed: {
        const QString text = error.detail.toLower();
        return text.contains(u"unrecognized subcommand") || text.contains(u"unexpected argument") ||
               text.contains(u"invalid value");
    }
    case MoatError::Kind::NotInstalled:
    case MoatError::Kind::TimedOut: return false;
    }
    return false;
}

// MARK: - Words

QString DetailsText::exposedHint() {
    return u"No deny rule covers its source: the agent can read the value there."_s;
}

QString DetailsText::coveredHint() {
    return u"The agent can't read the value where OpenMoat reads it."_s;
}

QString DetailsText::plainHttpHint() {
    return u"Also added to plain-HTTP requests, where it travels unencrypted."_s;
}

QString DetailsText::lint() {
    return u"moat policy lint"_s;
}

QString DetailsText::endsIn(std::int64_t expiresAtMs, std::int64_t nowMs) {
    const std::int64_t left = expiresAtMs - nowMs;
    if (left <= 0) {
        return u"Ended"_s;
    }
    const auto minutes = std::max<std::int64_t>(1, (left + 59999) / 60000);
    if (minutes < 60) {
        return u"Ends in %1 min"_s.arg(minutes);
    }
    const std::int64_t hours = minutes / 60;
    const std::int64_t rest = minutes % 60;
    return rest == 0 ? u"Ends in %1 h"_s.arg(hours) : u"Ends in %1 h %2 min"_s.arg(hours).arg(rest);
}

QString DetailsText::shortHash(const QString &sha256) {
    return sha256.left(12);
}

QString UpdateNotices::updateTitle() {
    return u"Policy update available"_s;
}

QString UpdateNotices::updateNote() {
    return u"moat policy upgrade shows each change and asks before it applies any."_s;
}

QString UpdateNotices::driftTitle() {
    return u"OpenMoat's files changed"_s;
}

QString UpdateNotices::driftNote() {
    return u"Files OpenMoat checks changed since it pinned them. moat doctor shows what changed."_s;
}

} // namespace moatbar
