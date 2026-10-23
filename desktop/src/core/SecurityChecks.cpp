#include "core/SecurityChecks.hpp"
#include "core/Details.hpp"
#include "core/Text.hpp"

#include <algorithm>
#include <functional>
#include <iterator>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

using Kind = SecurityCheck::Kind;

std::optional<SecurityCheck> agentCheck(const Protection &agent) {
    const QString id = u"agent-"_s + agent.host;
    switch (agent.level) {
    case Level::HookAndOsSandbox:
        return SecurityCheck{id, Kind::Ok, agent.name + u": every call checked, inside a sandbox"_s, {}, {}};
    case Level::HookOnly:
        return SecurityCheck{id, Kind::Info, agent.name + u": calls checked, no OS sandbox"_s, agent.reason,
                             CopyCommands::setUp()};
    case Level::NotProtected:
        // The agent's own settings file turns the hook off: running openmoat again
        // doesn't change that file, so say which file to edit.
        if (const auto file = hookTurnedOffBy(agent.reason)) {
            return SecurityCheck{id, Kind::Problem, agent.name + u" is not protected"_s,
                                 agent.reason.value_or(QString{}) + u". "_s + turnedOffAdvice(*file),
                                 CopyCommands::doctor()};
        }
        return SecurityCheck{id, Kind::Problem, agent.name + u" is not protected"_s, agent.reason,
                             CopyCommands::setUp()};
    case Level::NotSetUp:
        return SecurityCheck{id, Kind::Info, agent.name + u" is installed but not set up"_s,
                             u"openmoat asks before it changes anything and shows the diff."_s, CopyCommands::setUp()};
    case Level::NotFound:
    case Level::Unknown:
        return std::nullopt;
    }
    return std::nullopt;
}

SecurityCheck proxyCheck(const ProxyState &proxy) {
    const QString id = u"proxy"_s;
    const QString install = u"openmoat proxy install"_s;
    switch (proxy.kind) {
    case ProxyState::Kind::Running:
        return {id, Kind::Ok, u"Network proxy is running"_s, {}, {}};
    case ProxyState::Kind::NotInstalled:
        return {id, Kind::Info, u"Network proxy isn't kept running"_s,
                u"Without it, kept-back tokens can't be added to requests."_s, install};
    case ProxyState::Kind::Stopped:
        return {id, Kind::Warning, u"Network proxy is stopped"_s, {}, install};
    case ProxyState::Kind::DriftBlocked:
        return {id, Kind::Problem, u"Network proxy stopped after a watched file changed"_s,
                u"Look at the change first, then start the proxy again."_s, CopyCommands::doctor()};
    case ProxyState::Kind::Crashlooping:
        return {id, Kind::Warning, u"Network proxy keeps crashing"_s,
                u"Check the service log, then start it again."_s, install};
    case ProxyState::Kind::Unknown:
        return {id, Kind::Info, u"Network proxy: state unknown"_s, proxy.details, {}};
    }
    return {id, Kind::Info, u"Network proxy: state unknown"_s, {}, {}};
}

} // namespace

std::vector<SecurityCheck> securityChecks(const Snapshot &snapshot) {
    std::vector<SecurityCheck> checks;
    if (snapshot.moatVersion) {
        checks.push_back({u"moat"_s, Kind::Ok, u"openmoat %1 is installed"_s.arg(*snapshot.moatVersion), {}, {}});
    }
    for (const Protection &agent : snapshot.status.agents) {
        if (auto check = agentCheck(agent)) {
            checks.push_back(std::move(*check));
        }
    }
    if (snapshot.proxy) {
        checks.push_back(proxyCheck(*snapshot.proxy));
    }
    // OpenMoat 0.5.7 and later: pinned files that changed, a newer default policy.
    if (!snapshot.status.lockDrift.isEmpty()) {
        checks.push_back({u"lock"_s, Kind::Problem, UpdateNotices::driftTitle(),
                          snapshot.status.lockDrift.join(u'\n'), CopyCommands::doctor()});
    }
    // OpenMoat 0.5.7 and later; an older moat sends nothing, so no check.
    if (!snapshot.status.mcpChanges.isEmpty()) {
        const QStringList commands = McpNotices::acceptCommands(snapshot.status.mcpChanges);
        checks.push_back({u"mcp"_s, Kind::Warning, McpNotices::title(), snapshot.status.mcpChanges.join(u'\n'),
                          commands.size() == 1 ? commands.first() : CopyCommands::mcpAccept(std::nullopt)});
    }
    // OpenMoat 0.8.0 and later: a warning, as openmoat doctor counts it.
    if (!snapshot.status.projectSettings.isEmpty()) {
        checks.push_back({u"project-settings"_s, Kind::Warning, UpdateNotices::projectSettingsTitle(),
                          snapshot.status.projectSettings.join(u'\n'), CopyCommands::doctor()});
    }
    if (snapshot.status.policyUpdate) {
        checks.push_back({u"policy-update"_s, Kind::Info, UpdateNotices::updateTitle(), *snapshot.status.policyUpdate,
                          CopyCommands::policyUpgrade()});
    }
    // Worst first; within a kind, moat's order.
    std::ranges::stable_sort(checks, std::ranges::greater{}, &SecurityCheck::kind);
    return checks;
}

std::optional<QString> hookTurnedOffBy(const std::optional<QString> &reason) {
    constexpr QStringView prefix = u"hook turned off by ";
    if (!reason || !reason->startsWith(prefix)) {
        return std::nullopt;
    }
    const QString rest = reason->mid(prefix.size());
    // The file, then `: ` and what it sets; a path itself may hold a colon.
    const qsizetype end = rest.indexOf(u": "_s);
    const QString file = end < 0 ? rest : rest.left(end);
    if (file.isEmpty()) {
        return std::nullopt;
    }
    return file;
}

QString turnedOffAdvice(const QString &file) {
    return u"Edit %1 to remove what turns the hook off, then run openmoat doctor to check."_s.arg(file);
}

QString protectionFix(const Protection &agent) {
    return hookTurnedOffBy(agent.reason) ? CopyCommands::doctor() : CopyCommands::setUp();
}

std::vector<SecurityCheck> needingAttention(const std::vector<SecurityCheck> &checks) {
    std::vector<SecurityCheck> out;
    std::ranges::copy_if(checks, std::back_inserter(out),
                         [](const SecurityCheck &check) { return check.kind >= Kind::Warning; });
    return out;
}

} // namespace moatbar
