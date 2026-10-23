#include "app/TrayMenu.hpp"
#include "app/TrayIcon.hpp"
#include "core/Details.hpp"
#include "core/SecurityChecks.hpp"
#include "core/Text.hpp"

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QGuiApplication>
#include <QLocale>
#include <QPalette>

#include <algorithm>
#include <array>
#include <utility>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

void copy(const QString &text) {
    QGuiApplication::clipboard()->setText(text);
}

/// A line of information: shown, not clickable.
QAction *addNote(QMenu &menu, const QString &text) {
    QAction *action = menu.addAction(text);
    action->setEnabled(false);
    return action;
}

void addLink(QMenu &menu, const QString &title, const QUrl &url) {
    QObject::connect(menu.addAction(title + u" ↗"_s), &QAction::triggered, [url] {
        QDesktopServices::openUrl(url);
    });
}

void addCopy(QMenu &menu, const QString &title, const QString &command) {
    QAction *action = menu.addAction(u"%1: %2"_s.arg(title, command));
    action->setToolTip(u"Copies %1 to paste into a terminal"_s.arg(command));
    QObject::connect(action, &QAction::triggered, [command] { copy(command); });
}

QString clock(const QDateTime &time) {
    return QLocale().toString(time.time(), QLocale::ShortFormat);
}

QString shortPath(const QString &path) {
    const QString home = QDir::homePath();
    return path.startsWith(home) ? u"~"_s + path.mid(home.size()) : path;
}

/// Menu items are one line; keep long commands and paths readable.
QString elide(const QString &text, qsizetype length = 64) {
    QString line = text;
    line.replace(u'\n', u' ');
    return line.size() > length ? line.left(length - 1) + u"…"_s : line;
}

QIcon agentIcon(const QString &host) {
    QString resource;
    if (host == u"claude-code") {
        resource = u":/agent-claude@3x.png"_s;
    } else if (host == u"codex") {
        resource = u":/agent-codex@3x.png"_s;
    } else if (host == u"cursor") {
        resource = u":/agent-cursor@3x.png"_s;
    } else if (host == u"openclaw") {
        resource = u":/agent-openclaw@3x.png"_s;
    } else if (host == u"copilot-cli") {
        resource = u":/agent-copilot@3x.png"_s;
    } else if (host == u"pi") {
        resource = u":/agent-pi@3x.png"_s;
    } else if (host == u"gemini-cli") {
        resource = u":/agent-gemini@3x.png"_s;
    } else {
        return {};
    }
    return tintedIcon(resource, QGuiApplication::palette().color(QPalette::WindowText));
}

QString checkSymbol(SecurityCheck::Kind kind) {
    switch (kind) {
    case SecurityCheck::Kind::Ok: return u"✓"_s;
    case SecurityCheck::Kind::Info: return u"i"_s;
    case SecurityCheck::Kind::Warning:
    case SecurityCheck::Kind::Problem: return u"!"_s;
    }
    return {};
}

} // namespace

TrayMenu::TrayMenu(const Snapshot *snapshot, std::optional<MoatError> error, TrayActions actions)
    : m_snapshot(snapshot), m_error(std::move(error)), m_actions(std::move(actions)) {}

void TrayMenu::fill(QMenu &menu) const {
    menu.clear();
    // Desktops where a click on the icon opens this menu (GNOME's AppIndicator)
    // still reach the Quick View from here.
    if (m_actions.open) {
        QAction *open = menu.addAction(appIcon(), u"Open OpenMoat Bar"_s);
        QFont bold = open->font();
        bold.setBold(true);
        open->setFont(bold);
        QObject::connect(open, &QAction::triggered, m_actions.open);
        menu.addSeparator();
    }
    if (m_snapshot == nullptr) {
        addUnavailable(menu);
    } else {
        addHeader(menu);
        addProblems(menu);
        menu.addSeparator();
        addVerdicts(menu);
        menu.addSeparator();
        addAgents(menu);
        addChecks(menu);
    }
    addFooter(menu);
}

QString TrayMenu::agentName(const QString &host) const {
    return m_snapshot ? m_snapshot->agentName(host) : HostText::otherName(host);
}

// MARK: - Header and problems

void TrayMenu::addHeader(QMenu &menu) const {
    const auto installed = m_snapshot->installedAgents();
    const auto setUp = std::ranges::count_if(installed, [](const Protection &a) { return a.level != Level::NotSetUp; });
    const int total = std::max(static_cast<int>(setUp), m_snapshot->protectedCount());
    addNote(menu, u"OpenMoat Bar · %1 of %2 agents protected"_s.arg(m_snapshot->protectedCount()).arg(total))
        ->setIcon(appIcon());
    QString updated = m_error ? u"Last good data %1 · %2"_s.arg(clock(m_snapshot->takenAt), m_error->message())
                              : u"Updated %1"_s.arg(clock(m_snapshot->takenAt));
    if (m_snapshot->moatVersion) {
        updated += u" · openmoat "_s + *m_snapshot->moatVersion;
    }
    addNote(menu, updated);
}

void TrayMenu::addProblems(QMenu &menu) const {
    for (const Protection &agent : m_snapshot->unprotected()) {
        QMenu *problem = menu.addMenu(u"⚠ %1 is not protected"_s.arg(agent.name));
        if (agent.reason) {
            addNote(*problem, u"OpenMoat says: "_s + *agent.reason);
        }
        addNote(*problem, u"Its calls are not being checked."_s);
        addNote(*problem, u"Run openmoat in a terminal. It shows the change and asks first."_s);
        problem->addSeparator();
        addCopy(*problem, u"Copy the fix"_s, CopyCommands::setUp());
        addLink(*problem, u"Known limits"_s, DocsLink::limits());
    }
    // OpenMoat 0.5.7 and later: a newer default policy, pinned files that changed,
    // MCP server changes that wait for a person.
    const StatusReport &status = m_snapshot->status;
    if (status.policyUpdate) {
        QMenu *update = menu.addMenu(UpdateNotices::updateTitle());
        addNote(*update, u"OpenMoat says: "_s + *status.policyUpdate);
        addNote(*update, UpdateNotices::updateNote());
        update->addSeparator();
        addCopy(*update, u"Copy the command"_s, CopyCommands::policyUpgrade());
    }
    if (!status.lockDrift.isEmpty()) {
        QMenu *drift = menu.addMenu(u"⚠ "_s + UpdateNotices::driftTitle());
        for (const QString &line : status.lockDrift) {
            addNote(*drift, line);
        }
        addNote(*drift, UpdateNotices::driftNote());
        drift->addSeparator();
        addCopy(*drift, u"Copy the check command"_s, CopyCommands::doctor());
    }
    if (!status.mcpChanges.isEmpty()) {
        QMenu *mcp = menu.addMenu(u"⚠ "_s + McpNotices::title());
        for (const QString &line : status.mcpChanges) {
            addNote(*mcp, elide(line, 80));
        }
        addNote(*mcp, McpNotices::note());
        mcp->addSeparator();
        const QStringList commands = McpNotices::acceptCommands(status.mcpChanges);
        for (const QString &command : commands) {
            addCopy(*mcp, commands.size() == 1 ? u"Copy the command"_s : u"Copy"_s, command);
        }
    }
    // OpenMoat 0.8.0 and later: project settings files to review.
    if (!status.projectSettings.isEmpty()) {
        QMenu *settings = menu.addMenu(u"⚠ "_s + UpdateNotices::projectSettingsTitle());
        for (const QString &line : status.projectSettings) {
            addNote(*settings, elide(line, 80));
        }
        addNote(*settings, UpdateNotices::projectSettingsNote());
        settings->addSeparator();
        addCopy(*settings, u"Copy the check command"_s, CopyCommands::doctor());
    }
}

// MARK: - Verdicts, lists and decisions

void TrayMenu::addVerdicts(QMenu &menu) const {
    const VerdictCounts counts = m_snapshot->counts();
    for (const Verdict verdict : kVerdicts) {
        QMenu *list = menu.addMenu(u"%1  —  %2"_s.arg(verdictTitle(verdict), QLocale().toString(counts[verdict])));
        list->setToolTipsVisible(true);
        addNote(*list, verdictSubtitle(verdict));
        list->addSeparator();
        const auto events = m_snapshot->list(verdict);
        if (events.empty()) {
            addNote(*list, u"Nothing %1 today"_s.arg(verdictTitle(verdict).toLower()));
            continue;
        }
        const auto shown = std::min<std::size_t>(events.size(), kListLimit);
        for (std::size_t i = 0; i < shown; ++i) {
            const Event &event = events[i];
            const QString title = u"%1   ·  %2 · %3"_s.arg(elide(event.display(), 48),
                                                                      agentName(event.host), clock(event.time()));
            QMenu *decision = list->addMenu(agentIcon(event.host), title);
            addDecision(*decision, event);
        }
        if (events.size() > shown) {
            addNote(*list, u"%1 more"_s.arg(events.size() - shown));
        }
    }
}

void TrayMenu::addDecision(QMenu &menu, const Event &event) const {
    addNote(menu, u"%1 · %2"_s.arg(verdictTitle(event.verdict), event.rule().value_or(u"no rule"_s)));
    addNote(menu, u"%1 · %2 · %3"_s.arg(agentName(event.host), clock(event.time()), event.tool));
    addNote(menu, elide(event.display()));
    if (event.cwd) {
        addNote(menu, u"Folder: "_s + shortPath(*event.cwd));
    }
    if (const auto reason = event.reason()) {
        addNote(menu, u"Agent was told: "_s + elide(*reason));
    }
    if (const auto rule = event.rule()) {
        if (const auto why = RuleText::why(*rule)) {
            addNote(menu, u"Why: "_s + *why);
        }
    }
    if (const auto note = RuleText::driftNote(event.rules)) {
        addNote(menu, u"Note: "_s + *note);
    }
    menu.addSeparator();
    if (event.action) {
        if (const auto check = CopyCommands::policyCheck(*event.action)) {
            addCopy(menu, u"Copy check command"_s, *check);
        }
    }
    if (event.verdict == Verdict::Deny || event.verdict == Verdict::Ask) {
        addLink(menu, u"Why was this blocked?"_s, DocsLink::blocked());
        addLink(menu, u"Report a wrong block"_s, DocsLink::reportWrongBlock(event.rule()));
    } else {
        addLink(menu, u"How OpenMoat decides"_s, DocsLink::checkACommand());
    }
}

// MARK: - Agents and checks

void TrayMenu::addAgents(QMenu &menu) const {
    menu.addSection(u"Agents"_s);
    for (const Protection &agent : m_snapshot->status.agents) {
        const VerdictCounts counts = m_snapshot->counts(agent.host);
        QMenu *detail = menu.addMenu(agentIcon(agent.host), u"%1  —  %2"_s.arg(agent.name, levelLabel(agent.level)));
        if (agent.level == Level::NotFound) {
            addNote(*detail, u"%1 isn't installed on this computer."_s.arg(agent.name));
            addNote(*detail, u"Once it is, run openmoat to protect it."_s);
            continue;
        }
        addNote(*detail, u"Today: blocked %1 · asked %2 · %3 calls"_s.arg(counts[Verdict::Deny])
                              .arg(counts[Verdict::Ask])
                              .arg(counts.total()));
        if (const auto last = m_snapshot->lastCall(agent.host)) {
            addNote(*detail, u"Last call "_s + clock(*last));
        }
        if (agent.reason) {
            addNote(*detail, *agent.reason);
        }
        if (!agent.gaps.isEmpty()) {
            addNote(*detail, u"Not covered: "_s + elide(agent.gaps, 80));
        }
        detail->addSeparator();
        if (agent.level == Level::NotSetUp || agent.level == Level::NotProtected) {
            addCopy(*detail, u"Copy the set-up command"_s, CopyCommands::setUp());
        }
        addLink(*detail, u"Known limits"_s, DocsLink::limits());
    }
    if (m_snapshot->proxy) {
        addNote(menu, u"Network proxy: "_s + m_snapshot->proxy->label());
    }
}

void TrayMenu::addChecks(QMenu &menu) const {
    const auto checks = securityChecks(*m_snapshot);
    const auto attention = needingAttention(checks).size();
    menu.addSeparator();
    QMenu *sub = menu.addMenu(attention > 0 ? u"Security checks  —  %1 to look at"_s.arg(attention)
                                            : u"Security checks  —  all fine"_s);
    for (const SecurityCheck &check : checks) {
        addNote(*sub, checkSymbol(check.kind) + u"  "_s + check.title);
        if (check.detail) {
            addNote(*sub, u"     "_s + *check.detail);
        }
        if (check.fix && check.kind >= SecurityCheck::Kind::Info) {
            addCopy(*sub, u"     Copy the fix"_s, *check.fix);
        }
    }
    sub->addSeparator();
    addCopy(*sub, u"Copy for every check"_s, CopyCommands::doctor());
}

// MARK: - Unavailable and footer

void TrayMenu::addUnavailable(QMenu &menu) const {
    if (!m_error || m_error->kind == MoatError::Kind::NotInstalled) {
        addNote(menu, u"OpenMoat isn't installed"_s)->setIcon(trayIcon(IconState::Unavailable));
        addNote(menu, u"Without it, your agents run with only their own prompts."_s);
        menu.addSeparator();
        addCopy(menu, u"Copy the install command"_s, CopyCommands::install());
        addLink(menu, u"Install guide"_s, DocsLink::quickstart());
    } else {
        addNote(menu, u"Couldn't read OpenMoat"_s);
        addNote(menu, m_error->message());
        addNote(menu, u"Your agents are still checked; only this view is out of date."_s);
        menu.addSeparator();
        addCopy(menu, u"Copy the check command"_s, CopyCommands::doctor());
    }
}

void TrayMenu::addFooter(QMenu &menu) const {
    menu.addSeparator();
    if (m_actions.activity) {
        QObject::connect(menu.addAction(u"Activity window…"_s), &QAction::triggered, m_actions.activity);
    }
    if (m_actions.details) {
        const std::array pages{std::pair{u"What you allowed…"_s, u"allowed"_s}, std::pair{u"Secrets…"_s, u"secrets"_s},
                               std::pair{u"Checks…"_s, u"checks"_s}};
        for (const auto &entry : pages) {
            QObject::connect(menu.addAction(entry.first), &QAction::triggered,
                             [open = m_actions.details, page = entry.second] { open(page); });
        }
    }
    QObject::connect(menu.addAction(u"Refresh"_s), &QAction::triggered, m_actions.refresh);
    addLink(menu, u"OpenMoat docs"_s, DocsLink::home());
    menu.addSeparator();
    if (m_actions.settings) {
        QObject::connect(menu.addAction(u"Settings…"_s), &QAction::triggered, m_actions.settings);
    }
    QObject::connect(menu.addAction(u"About OpenMoat Bar"_s), &QAction::triggered, m_actions.about);
    QObject::connect(menu.addAction(u"Quit OpenMoat Bar"_s), &QAction::triggered, m_actions.quit);
}

} // namespace moatbar
