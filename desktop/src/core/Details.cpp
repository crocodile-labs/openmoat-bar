#include "core/Details.hpp"
#include "core/Text.hpp"

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
    case Kind::Unknown: return u"a source this version of OpenMoat Bar doesn't know"_s;
    }
    return u"a source this version of OpenMoat Bar doesn't know"_s;
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

QString doctorTopicLabel(DoctorTopic topic) {
    switch (topic) {
    case DoctorTopic::Moat: return u"OpenMoat"_s;
    case DoctorTopic::Policy: return u"Policy"_s;
    case DoctorTopic::Lock: return u"Pinned files"_s;
    case DoctorTopic::Hooks: return u"Hooks"_s;
    case DoctorTopic::Mcp: return u"MCP servers"_s;
    case DoctorTopic::Sandbox: return u"Sandboxes"_s;
    case DoctorTopic::Proxy: return u"Network proxy"_s;
    case DoctorTopic::Agents: return u"Agents"_s;
    case DoctorTopic::Audit: return u"Audit log"_s;
    case DoctorTopic::Other: return u"Other"_s;
    }
    return u"Other"_s;
}

QString DoctorCheck::title() const {
    return name.isEmpty() ? detail : CheckText::label(name);
}

DoctorTopic DoctorCheck::topic() const {
    // `area` in openmoat crates/openmoat-cli/src/commands/doctor.rs.
    if (area) {
        const QString &a = *area;
        if (a == u"state" || a == u"binary" || a == u"environment") {
            return DoctorTopic::Moat;
        }
        if (a == u"policy") {
            return DoctorTopic::Policy;
        }
        if (a == u"lock") {
            return DoctorTopic::Lock;
        }
        if (a == u"hook") {
            return DoctorTopic::Hooks;
        }
        if (a == u"mcp") {
            return DoctorTopic::Mcp;
        }
        if (a == u"sandbox") {
            return DoctorTopic::Sandbox;
        }
        if (a == u"service") {
            return DoctorTopic::Proxy;
        }
        if (a == u"audit") {
            return DoctorTopic::Audit;
        }
        return DoctorTopic::Other;
    }
    const QString lower = name.toLower();
    if (lower == u"audit log" || lower == u"audit anchor") {
        return DoctorTopic::Audit;
    }
    if (lower == u"repo policy" || lower == u"policy update") {
        return DoctorTopic::Policy;
    }
    if (lower == u"mcp servers" || lower == u"mcp tools") {
        return DoctorTopic::Mcp;
    }
    if (lower == u"guard" || lower == u"hook file") {
        return DoctorTopic::Hooks;
    }
    // The rows about the `moat` name and `openmoat run` (openmoat doctor/warnings.rs).
    if (lower == u"command" || lower == u"binary" || lower == u"state directory" || lower == u"environment" ||
        lower == u"openmoat run" || lower == u"moat run") {
        return DoctorTopic::Moat;
    }
    if (detail.contains(u"onFailure") || detail.startsWith(u"hook runs the old")) {
        // `Claude Code      runs a tool call when its hook fails…`, and after the
        // rename `Claude Code      hook runs the old `moat` name…`.
        return DoctorTopic::Hooks;
    }
    // How the notes about one agent start (`Claude Code      protection: …`), and
    // the warning about a project settings file that agent loads (`Claude Code
    // project settings /path: …`; openmoat commands/doctor.rs).
    constexpr std::array agentLines{QStringView{u"protection:"}, QStringView{u"known gaps:"},
                                    QStringView{u"host not found"}, QStringView{u"not set up"},
                                    QStringView{u"project settings "}};
    if (!lower.isEmpty() &&
        std::ranges::any_of(agentLines, [this](QStringView start) { return detail.startsWith(start); })) {
        return DoctorTopic::Agents;
    }
    return DoctorTopic::Other;
}

std::vector<DoctorGroup> DoctorReport::groups() const {
    constexpr std::array order{DoctorStatus::Problem, DoctorStatus::Warning, DoctorStatus::Note, DoctorStatus::Ok};
    std::vector<DoctorGroup> out;
    for (const DoctorStatus status : order) {
        DoctorGroup group{status, {}};
        std::ranges::copy_if(checks, std::back_inserter(group.checks),
                             [status](const DoctorCheck &check) { return check.status == status; });
        // Stable: within a topic, moat's order.
        std::ranges::stable_sort(group.checks, std::ranges::less{}, &DoctorCheck::topic);
        if (!group.checks.empty()) {
            out.push_back(std::move(group));
        }
    }
    return out;
}

// MARK: - Check words

QString CheckText::label(const QString &name) {
    const QString lower = name.toLower();
    if (lower == u"command") {
        return u"Command name"_s;
    }
    if (lower == u"audit anchor") {
        return u"Audit anchor"_s;
    }
    if (lower == u"audit log") {
        return u"Audit log"_s;
    }
    if (lower == u"repo policy") {
        return u"Repository policy"_s;
    }
    if (lower == u"policy update") {
        return u"Policy update"_s;
    }
    if (lower == u"mcp servers") {
        return u"MCP servers"_s;
    }
    if (lower == u"mcp tools") {
        return u"MCP tools"_s;
    }
    return name;
}

std::optional<QString> CheckText::hint(const DoctorCheck &check) {
    const QString name = check.name.toLower();
    const QString &detail = check.detail;
    switch (check.topic()) {
    case DoctorTopic::Audit:
        if (name == u"audit anchor") {
            return u"A copy of the audit log's latest hash, kept outside it. "
                   u"openmoat audit verify --against checks the log against it later."_s;
        }
        return std::nullopt;
    case DoctorTopic::Policy:
        return name == u"repo policy" ? repoPolicyHint(detail) : std::nullopt;
    case DoctorTopic::Mcp:
        if (detail.contains(u"not pinned yet")) {
            return u"Once pinned, a server definition that changes later is held back until you accept it."_s;
        }
        if (check.status == DoctorStatus::Problem) {
            return u"Its tool calls are refused until you accept the change."_s;
        }
        return std::nullopt;
    case DoctorTopic::Hooks:
        if (detail.contains(u"onFailure")) {
            return u"With this Claude Code, a tool call still runs when the OpenMoat hook crashes or times out."_s;
        }
        return std::nullopt;
    case DoctorTopic::Lock:
        if (isPackFile(detail)) {
            return u"A signed policy pack changed after it was installed. Calls stop until a person looks."_s;
        }
        return std::nullopt;
    case DoctorTopic::Moat:
    case DoctorTopic::Sandbox:
    case DoctorTopic::Proxy:
    case DoctorTopic::Agents:
    case DoctorTopic::Other: return std::nullopt;
    }
    return std::nullopt;
}

std::optional<QString> CheckText::fix(const DoctorCheck &check) {
    if (check.topic() != DoctorTopic::Mcp || check.status == DoctorStatus::Ok) {
        return std::nullopt;
    }
    return CopyCommands::mcpAccept(quotedName(check.detail));
}

std::optional<QString> CheckText::repoPolicyHint(const QString &detail) {
    constexpr QStringView signedBy = u"trusted: signed by ";
    if (const qsizetype at = detail.indexOf(signedBy); at >= 0) {
        const QString signer = detail.mid(at + signedBy.size()).section(u' ', 0, 0);
        return u"Signed by %1, a key you trust, so its allow rules apply too."_s.arg(signer);
    }
    if (detail.contains(u"not signed by a trusted key")) {
        return u"Not signed by a key you trust, so only its deny and ask rules apply."_s;
    }
    if (detail.contains(u"changed since `")) {
        return u"Changed since you trusted it, so only its deny and ask rules apply."_s;
    }
    if (detail.contains(u"not trusted")) {
        return u"Not trusted, so only its deny and ask rules apply."_s;
    }
    if (detail.contains(u"tightening only")) {
        return u"It only adds deny and ask rules."_s;
    }
    if (detail.contains(u"trusted (")) {
        return u"Trusted with openmoat trust, so its allow rules apply too."_s;
    }
    return std::nullopt;
}

bool CheckText::isPackFile(const QString &detail) {
    return detail.contains(u"policy.d/packs/") || detail.contains(u"policy.d\\packs\\") ||
           detail.contains(u"packs.json");
}

std::optional<QString> CheckText::quotedName(const QString &text) {
    const qsizetype start = text.indexOf(u'`');
    if (start < 0) {
        return std::nullopt;
    }
    const qsizetype end = text.indexOf(u'`', start + 1);
    if (end < 0) {
        return std::nullopt;
    }
    const QString name = text.mid(start + 1, end - start - 1);
    // `openmoat mcp accept` in the "not pinned yet" line is a command, not a server.
    if (name.isEmpty() || name.contains(u' ')) {
        return std::nullopt;
    }
    return name;
}

// MARK: - Older moat

QString MoatRequirement::note(QStringView minimum) {
    return u"This needs OpenMoat %1 or later. Update OpenMoat to see it here."_s.arg(minimum);
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

QString DetailsText::plainHttpHint(const BrokeredSecret &secret) {
    return u"Also added to plain-HTTP requests on port %1, where it travels unencrypted."_s.arg(
        secret.port.value_or(80));
}

QString DetailsText::grantAppliesNowhere() {
    return u"Names no project, so it applies nowhere: approve it again"_s;
}

QString DetailsText::grantLine(const SessionGrant &grant, const QString &agent, std::int64_t nowMs) {
    QStringList parts{agent, u"session "_s + grant.sessionId.left(8)};
    if (!grant.applies) {
        parts << grantAppliesNowhere();
        return parts.join(u" · "_s);
    }
    if (grant.project && !grant.project->isEmpty()) {
        parts << u"in "_s + *grant.project;
    }
    parts << endsIn(grant.expiresAtMs, nowMs);
    return parts.join(u" · "_s);
}

QString DetailsText::lint() {
    return u"openmoat policy lint"_s;
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
    return u"openmoat policy upgrade shows each change and asks before it applies any."_s;
}

QString UpdateNotices::driftTitle() {
    return u"OpenMoat's files changed"_s;
}

QString UpdateNotices::driftNote() {
    return u"Files OpenMoat checks changed since it pinned them. openmoat doctor shows what changed."_s;
}

QString UpdateNotices::projectSettingsTitle() {
    return u"Project settings need a look"_s;
}

QString UpdateNotices::projectSettingsNote() {
    return u"An agent loads these when a session starts in that folder, before any hook runs, "
           u"so OpenMoat can only point at them."_s;
}

} // namespace moatbar
