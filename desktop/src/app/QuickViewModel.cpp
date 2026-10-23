#include "app/QuickViewModel.hpp"
#include "app/EventViews.hpp"
#include "core/Details.hpp"
#include "core/Format.hpp"
#include "core/SecurityChecks.hpp"
#include "core/Text.hpp"

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QGuiApplication>

#include <algorithm>

using namespace Qt::StringLiterals;
using namespace std::chrono_literals;

namespace moatbar {
namespace {

/// The colour role QML draws a level in.
QString levelTone(Level level) {
    switch (level) {
    case Level::HookAndOsSandbox: return u"ok"_s;
    case Level::HookOnly: return u"warn"_s;
    case Level::NotProtected: return u"bad"_s;
    case Level::NotSetUp:
    case Level::NotFound:
    case Level::Unknown: return u"muted"_s;
    }
    return u"muted"_s;
}

QString checkTone(SecurityCheck::Kind kind) {
    switch (kind) {
    case SecurityCheck::Kind::Ok: return u"ok"_s;
    case SecurityCheck::Kind::Info: return u"info"_s;
    case SecurityCheck::Kind::Warning: return u"warn"_s;
    case SecurityCheck::Kind::Problem: return u"bad"_s;
    }
    return u"info"_s;
}

bool needsSetUp(Level level) {
    return level == Level::NotSetUp || level == Level::NotProtected;
}

QVariantMap countsMap(const VerdictCounts &counts) {
    return {
        {u"deny"_s, counts[Verdict::Deny]},
        {u"ask"_s, counts[Verdict::Ask]},
        {u"deferred"_s, counts[Verdict::Deferred]},
        {u"allow"_s, counts[Verdict::Allow]},
        {u"total"_s, counts.total()},
    };
}

} // namespace

QuickViewModel::QuickViewModel(QObject *parent) : QObject(parent), m_now(QDateTime::currentDateTime()) {
    m_settle.setSingleShot(true);
    connect(&m_settle, &QTimer::timeout, this, [this] { setRefresh(u"idle"_s, {}); });
}

void QuickViewModel::setData(const std::optional<Snapshot> &snapshot, const std::optional<MoatError> &error,
                             const QDateTime &now) {
    m_snapshot = snapshot;
    m_error = error;
    m_now = now;
    // Forget a tab whose agent moat no longer reports.
    if (!m_selectedHost.isEmpty() && (!m_snapshot || m_snapshot->agent(m_selectedHost) == nullptr)) {
        m_selectedHost.clear();
    }
    ++m_revision;
    emit changed();
}

void QuickViewModel::setSelectedHost(const QString &host) {
    const QString valid = (m_snapshot && m_snapshot->agent(host) != nullptr) ? host : QString{};
    if (valid == m_selectedHost) {
        return;
    }
    m_selectedHost = valid;
    ++m_revision;
    emit changed();
}

QString QuickViewModel::agentName(const QString &host) const {
    return m_snapshot ? m_snapshot->agentName(host) : HostText::otherName(host);
}

// MARK: - Unavailable, tabs, header, problems

QVariantMap QuickViewModel::unavailable() const {
    if (m_snapshot) {
        return {};
    }
    if (!m_error || m_error->kind == MoatError::Kind::NotInstalled) {
        return {
            {u"title"_s, u"OpenMoat isn't installed"_s},
            {u"text"_s, u"MoatBar shows what OpenMoat does. Without it, your agents run with only their own prompts."_s},
            {u"note"_s, u"MoatBar looks for openmoat again every minute."_s},
            {u"tone"_s, u"muted"_s},
            {u"commandTitle"_s, u"Copy the install command"_s},
            {u"command"_s, CopyCommands::install()},
            {u"docs"_s, u"quickstart"_s},
            {u"docsTitle"_s, u"Install guide"_s},
        };
    }
    return {
        {u"title"_s, u"Couldn't read OpenMoat"_s},
        {u"text"_s, QString(m_error->message() + u". Your agents are still checked; only this view is out of date."_s)},
        {u"note"_s, u"openmoat doctor shows what is wrong."_s},
        {u"tone"_s, u"warn"_s},
        {u"commandTitle"_s, u"Copy the check command"_s},
        {u"command"_s, CopyCommands::doctor()},
    };
}

QVariantList QuickViewModel::tabs() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList out;
    out << QVariantMap{{u"host"_s, QString{}}, {u"name"_s, u"All"_s}, {u"tone"_s, QString{}}, {u"installed"_s, true}};
    for (const Protection &agent : m_snapshot->status.agents) {
        out << QVariantMap{
            {u"host"_s, agent.host},
            {u"name"_s, HostText::shortName(agent.name)},
            {u"tone"_s, levelTone(agent.level)},
            {u"installed"_s, agent.level != Level::NotFound},
        };
    }
    return out;
}

QVariantMap QuickViewModel::header() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantMap out;
    if (const Protection *agent = m_snapshot->agent(host())) {
        out[u"title"_s] = agent->name;
        out[u"detail"_s] = levelLabel(agent->level);
        out[u"tone"_s] = levelTone(agent->level);
    } else {
        const auto installed = m_snapshot->installedAgents();
        const auto setUp =
            std::ranges::count_if(installed, [](const Protection &a) { return a.level != Level::NotSetUp; });
        const int protectedCount = m_snapshot->protectedCount();
        out[u"title"_s] = u"All agents"_s;
        out[u"detail"_s] = u"%1 of %2 protected"_s.arg(protectedCount).arg(std::max<qsizetype>(setUp, protectedCount));
        out[u"tone"_s] = m_snapshot->unprotected().empty() ? u"ok"_s : u"bad"_s;
    }
    out[u"updated"_s] = m_error ? u"Last good data %1 · %2"_s.arg(Format::clock(m_snapshot->takenAt), m_error->message())
                                : u"Updated %1"_s.arg(Format::relative(m_snapshot->takenAt, m_now));
    out[u"version"_s] = m_snapshot->moatVersion ? QString(u"openmoat "_s + *m_snapshot->moatVersion) : QString{};
    return out;
}

QVariantList QuickViewModel::problems() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList out;
    for (const Protection &agent : m_snapshot->unprotected()) {
        if (!m_selectedHost.isEmpty() && agent.host != m_selectedHost) {
            continue;
        }
        const QString why = agent.reason ? u"OpenMoat says: %1. "_s.arg(*agent.reason) : QString{};
        out << QVariantMap{
            {u"title"_s, u"%1 is not protected"_s.arg(agent.name)},
            {u"text"_s, QString(why + u"Its calls are not being checked."_s)},
            {u"note"_s, u"Run openmoat in a terminal. It shows the change and asks first. "
                        u"This goes away on the next check."_s},
            {u"command"_s, CopyCommands::setUp()},
        };
    }
    return out;
}

QVariantList QuickViewModel::notices() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList out;
    const StatusReport &status = m_snapshot->status;
    if (status.policyUpdate) {
        out << QVariantMap{
            {u"title"_s, UpdateNotices::updateTitle()},
            {u"text"_s, u"OpenMoat says: %1."_s.arg(*status.policyUpdate)},
            {u"note"_s, UpdateNotices::updateNote()},
            {u"tone"_s, u"info"_s},
            {u"commandTitle"_s, u"Copy the command"_s},
            {u"command"_s, CopyCommands::policyUpgrade()},
        };
    }
    if (!status.lockDrift.isEmpty()) {
        out << QVariantMap{
            {u"title"_s, UpdateNotices::driftTitle()},
            {u"text"_s, status.lockDrift.join(u'\n')},
            {u"note"_s, UpdateNotices::driftNote()},
            {u"tone"_s, u"warn"_s},
            {u"commandTitle"_s, u"Copy the check command"_s},
            {u"command"_s, CopyCommands::doctor()},
        };
    }
    if (!status.mcpChanges.isEmpty()) {
        // One copy row per server: `openmoat mcp accept gh`, `openmoat mcp accept docs`.
        const QStringList commands = McpNotices::acceptCommands(status.mcpChanges);
        out << QVariantMap{
            {u"title"_s, McpNotices::title()},
            {u"text"_s, status.mcpChanges.join(u'\n')},
            {u"note"_s, McpNotices::note()},
            {u"tone"_s, u"warn"_s},
            {u"commandTitle"_s, commands.size() == 1 ? u"Copy the command"_s : u"Copy"_s},
            {u"command"_s, commands.first()},
            {u"moreCommands"_s, QStringList(commands.mid(1))},
        };
    }
    if (!status.projectSettings.isEmpty()) {
        out << QVariantMap{
            {u"title"_s, UpdateNotices::projectSettingsTitle()},
            {u"text"_s, status.projectSettings.join(u'\n')},
            {u"note"_s, UpdateNotices::projectSettingsNote()},
            {u"tone"_s, u"warn"_s},
            {u"commandTitle"_s, u"Copy the check command"_s},
            {u"command"_s, CopyCommands::doctor()},
        };
    }
    return out;
}

// MARK: - Today and verdicts

QVariantMap QuickViewModel::today() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList hours;
    int peak = 1;
    for (const VerdictCounts &counts : m_snapshot->hourly(host(), m_now.timeZone())) {
        hours << countsMap(counts);
        peak = std::max(peak, counts.total());
    }
    return {
        {u"hours"_s, hours},
        {u"peak"_s, peak},
        {u"total"_s, static_cast<int>(m_snapshot->eventsFor(host()).size())},
        {u"sessions"_s, static_cast<int>(m_snapshot->sessions(host()).size())},
        {u"currentHour"_s, m_now.time().hour()},
    };
}

QVariantList QuickViewModel::verdicts() const {
    if (!m_snapshot) {
        return {};
    }
    const VerdictCounts counts = m_snapshot->counts(host());
    QVariantList out;
    for (const Verdict verdict : kVerdicts) {
        out << QVariantMap{
            {u"key"_s, verdictKey(verdict)},
            {u"title"_s, verdictTitle(verdict)},
            {u"subtitle"_s, verdictSubtitle(verdict)},
            {u"count"_s, counts[verdict]},
            {u"countText"_s, Format::count(counts[verdict])},
        };
    }
    return out;
}

QVariantList QuickViewModel::events(const QString &verdict) const {
    const auto which = verdictFromKey(verdict);
    if (!m_snapshot || !which) {
        return {};
    }
    const auto events = m_snapshot->list(*which, host());
    QVariantList out;
    const auto shown = std::min<std::size_t>(events.size(), kListLimit);
    for (std::size_t i = 0; i < shown; ++i) {
        out << eventRowMap(events[i], agentName(events[i].host));
    }
    return out;
}

int QuickViewModel::moreEvents(const QString &verdict) const {
    const auto which = verdictFromKey(verdict);
    if (!m_snapshot || !which) {
        return 0;
    }
    const auto size = static_cast<int>(m_snapshot->list(*which, host()).size());
    return std::max(0, size - kListLimit);
}

QVariantMap QuickViewModel::decision(const QString &id) const {
    if (!m_snapshot) {
        return {};
    }
    const auto it = std::ranges::find(m_snapshot->events, id, &Event::id);
    if (it == m_snapshot->events.end()) {
        return {};
    }
    return decisionMap(*it, agentName(it->host));
}

// MARK: - Agents, sessions, checks

QVariantList QuickViewModel::agents() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList out;
    for (const Protection &agent : m_snapshot->installedAgents()) {
        const VerdictCounts counts = m_snapshot->counts(agent.host);
        QString detail = u"Today: %1 calls · %2 blocked"_s.arg(counts.total()).arg(counts[Verdict::Deny]);
        if (const auto last = m_snapshot->lastCall(agent.host)) {
            detail += u" · last "_s + Format::relative(*last, m_now);
        }
        out << QVariantMap{
            {u"host"_s, agent.host},
            {u"name"_s, agent.name},
            {u"level"_s, levelLabel(agent.level)},
            {u"tone"_s, levelTone(agent.level)},
            {u"detail"_s, detail},
        };
    }
    return out;
}

QVariantMap QuickViewModel::agentDetail() const {
    const Protection *agent = m_snapshot ? m_snapshot->agent(host()) : nullptr;
    if (agent == nullptr) {
        return {};
    }
    const auto last = m_snapshot->lastCall(agent->host);
    return {
        {u"host"_s, agent->host},
        {u"name"_s, agent->name},
        {u"level"_s, levelLabel(agent->level)},
        {u"tone"_s, levelTone(agent->level)},
        {u"reason"_s, agent->reason.value_or(QString{})},
        {u"gaps"_s, agent->gaps},
        {u"lastCall"_s, last ? Format::relative(*last, m_now) : QString{}},
        {u"installed"_s, agent->level != Level::NotFound},
        {u"setUpCommand"_s, needsSetUp(agent->level) ? CopyCommands::setUp() : QString{}},
    };
}

QVariantList QuickViewModel::sessions() const {
    if (!m_snapshot || m_selectedHost.isEmpty()) {
        return {};
    }
    QVariantList out;
    for (const Session &session : m_snapshot->sessions(host())) {
        const QString folder = session.cwd ? Format::shortPath(*session.cwd, QDir::homePath()) : session.id;
        out << QVariantMap{
            {u"title"_s, folder},
            {u"detail"_s, u"%1–%2 · %3 calls · %4 blocked"_s.arg(Format::clock(session.first), Format::clock(session.last))
                              .arg(session.counts.total())
                              .arg(session.counts[Verdict::Deny])},
        };
    }
    return out;
}

QString QuickViewModel::proxy() const {
    return (m_snapshot && m_snapshot->proxy) ? m_snapshot->proxy->label() : QString{};
}

QVariantList QuickViewModel::checks() const {
    if (!m_snapshot) {
        return {};
    }
    QVariantList out;
    for (const SecurityCheck &check : securityChecks(*m_snapshot)) {
        out << QVariantMap{
            {u"id"_s, check.id},
            {u"tone"_s, checkTone(check.kind)},
            {u"title"_s, check.title},
            {u"detail"_s, check.detail.value_or(QString{})},
            {u"fix"_s, check.kind >= SecurityCheck::Kind::Info ? check.fix.value_or(QString{}) : QString{}},
        };
    }
    return out;
}

QString QuickViewModel::checksHint() const {
    if (!m_snapshot) {
        return {};
    }
    const auto attention = needingAttention(securityChecks(*m_snapshot)).size();
    return attention > 0 ? u"%1 to look at"_s.arg(attention) : u"all fine"_s;
}

QString QuickViewModel::doctorCommand() const {
    return CopyCommands::doctor();
}

// MARK: - Actions

void QuickViewModel::refresh() {
    if (!m_refreshHandler || m_refreshState == u"refreshing") {
        return;
    }
    setRefresh(u"refreshing"_s, u"Reading OpenMoat…"_s);
    m_refreshHandler();
}

void QuickViewModel::refreshFinished(const std::optional<MoatError> &error) {
    if (m_refreshState != u"refreshing") {
        return;
    }
    if (error) {
        setRefresh(u"failed"_s, error->message());
        m_settle.start(5s);
    } else {
        setRefresh(u"done"_s, u"Updated just now"_s);
        m_settle.start(3s);
    }
}

void QuickViewModel::setRefresh(const QString &state, const QString &text) {
    m_refreshState = state;
    m_refreshText = text;
    emit refreshChanged();
}

void QuickViewModel::copy(const QString &text) {
    if (auto *clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
    }
}

void QuickViewModel::openDocs(const QString &page) {
    QUrl url;
    if (page == u"blocked") {
        url = DocsLink::blocked();
    } else if (page == u"check") {
        url = DocsLink::checkACommand();
    } else if (page == u"quickstart") {
        url = DocsLink::quickstart();
    } else if (page == u"limits") {
        url = DocsLink::limits();
    } else if (page == u"turn-off") {
        url = DocsLink::turnOff();
    } else {
        url = DocsLink::home();
    }
    QDesktopServices::openUrl(url);
}

void QuickViewModel::reportWrongBlock(const QString &rule) {
    QDesktopServices::openUrl(DocsLink::reportWrongBlock(rule.isEmpty() ? std::nullopt : std::optional{rule}));
}

} // namespace moatbar
