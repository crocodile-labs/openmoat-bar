#include "core/Text.hpp"

#include <QUrlQuery>

#include <algorithm>
#include <array>

using namespace Qt::StringLiterals;

namespace moatbar {

namespace {

/// Rule id and its words; the macOS app's RuleText.swift has the same table.
struct RuleWords {
    QStringView rule;
    QStringView words;
};

constexpr std::array kRuleWords{
    RuleWords{u"secrets-paths",
              u"Private keys, .env files and cloud credentials hold passwords and tokens. Agents never read them."},
    RuleWords{u"destructive",
              u"This throws away work that can't be brought back, like uncommitted changes or a home folder."},
    RuleWords{u"pipe-to-shell", u"Running a script straight from the internet means running code nobody has looked at."},
    RuleWords{u"env-secrets",
              u"Printing environment variables would show tokens to the agent and to whatever it talks to."},
    RuleWords{u"env-dump", u"Printing environment variables would show tokens to the agent and to whatever it talks to."},
    RuleWords{u"shell-rc", u"Changing your shell's startup files would run code in every terminal you open later."},
    RuleWords{u"kernel-self",
              u"Agents can't change OpenMoat's own rules, hooks or binary. Only a person can, in a terminal."},
    RuleWords{u"kernel-integrity",
              u"A file OpenMoat watches was changed outside OpenMoat, so calls stop until a person looks."},
    RuleWords{u"git-internals", u"This changes which hooks git runs, which would run code on later git commands."},
    RuleWords{u"runs-later", u"This changes something that runs on its own later, like CI settings or editor tasks."},
    RuleWords{u"default.net", u"The agent tried to reach a site that isn't on the allowed list."},
    RuleWords{u"default", u"No rule covers this, so the agent's own prompt decided."},
    RuleWords{u"dev-shell", u"A normal development command, like building or testing."},
    RuleWords{u"project-fs", u"Reading or writing files inside the project."},
    RuleWords{u"package-near-miss",
              u"The package name is one typo away from a popular one, a common trick for slipping in a look-alike."},
    RuleWords{u"push-secret", u"The push would publish a token or a brokered secret's value in a commit."},
    RuleWords{u"push-runs-later",
              u"After reading untrusted content, the agent pushes a change to a file CI runs with your secrets."},
    RuleWords{u"push-unchecked", u"OpenMoat couldn't check what this push publishes in time, so it asks."},
    RuleWords{u"token-egress", u"A known kind of token was about to go to a host that isn't its own service."},
    RuleWords{u"placeholder-egress",
              u"A brokered secret's placeholder was about to go to a host that secret isn't for."},
    RuleWords{u"mcp-server-changed", u"This MCP server's definition changed since a person accepted it, so its tools "
                                     u"wait for openmoat mcp accept."},
    RuleWords{u"mcp-tool-held",
              u"This MCP tool's description or inputs changed, so it stays hidden until a person accepts it."},
    RuleWords{u"settings-drift", u"A settings file OpenMoat pinned changed in a way that changes no decision, so "
                                 u"calls are decided as usual."},
};

} // namespace

std::optional<QString> RuleText::why(QStringView rule) {
    for (const RuleWords &entry : kRuleWords) {
        if (entry.rule == rule) {
            return entry.words.toString();
        }
    }
    // `pack:<name>:<id>`: a rule from a signed policy pack (openmoat `packs.rs`).
    if (rule.startsWith(u"pack:")) {
        const QStringView name = rule.mid(5).split(u':').value(0);
        if (name.isEmpty()) {
            return u"A rule from a signed policy pack you installed."_s;
        }
        return u"A rule from the policy pack %1, installed after its signature checked out."_s.arg(name);
    }
    // `repo:<id>`: a rule from the project's `.moat/policy.yaml` (openmoat `repo.rs`).
    if (rule.startsWith(u"repo:")) {
        return u"A rule from this repository's own OpenMoat policy file."_s;
    }
    return std::nullopt;
}

std::optional<QString> RuleText::driftNote(const QStringList &rules) {
    if (rules.isEmpty() || rules.first() == settingsDrift() || !rules.contains(settingsDrift())) {
        return std::nullopt;
    }
    return u"A settings file OpenMoat pinned changed in a way that changes no decision. "
           u"openmoat doctor shows the change."_s;
}

QString HostText::shortName(const QString &name) {
    if (name == u"Claude Code") {
        return u"Claude"_s;
    }
    if (name == u"GitHub Copilot CLI") {
        return u"Copilot"_s;
    }
    if (name == u"Gemini CLI") {
        return u"Gemini"_s;
    }
    return name;
}

QString HostText::otherName(const QString &host) {
    if (host == u"proxy") {
        return u"Network proxy"_s;
    }
    if (host == u"mcp-proxy") {
        return u"MCP proxy"_s;
    }
    if (host == u"moat-run") {
        return u"openmoat run"_s;
    }
    return host;
}

QString CopyCommands::setUp() {
    return u"openmoat"_s;
}

QString CopyCommands::doctor() {
    return u"openmoat doctor"_s;
}

QString CopyCommands::install(Shell shell) {
    if (shell == Shell::PowerShell) {
        return u"powershell -ExecutionPolicy Bypass -c \"irm "
               u"https://github.com/crocodile-labs/openmoat/releases/latest/download/openmoat-installer.ps1 | iex\""_s;
    }
    return u"brew install crocodile-labs/tap/openmoat"_s;
}

QString CopyCommands::policyUpgrade() {
    return u"openmoat policy upgrade"_s;
}

QString CopyCommands::mcpAccept(const std::optional<QString> &server, Shell shell) {
    if (!server || server->isEmpty()) {
        return u"openmoat mcp accept"_s;
    }
    return u"openmoat mcp accept "_s + quoteIfNeeded(*server, shell);
}

QString CopyCommands::removeRule(const QString &id, Shell shell) {
    return u"openmoat allow --remove "_s + quoteIfNeeded(id, shell);
}

QString CopyCommands::revokeTrust(const QString &root, Shell shell) {
    return u"openmoat trust --revoke "_s + quoteIfNeeded(root, shell);
}

QString CopyCommands::quoteIfNeeded(const QString &text, Shell shell) {
    // Backslashes are path separators in PowerShell and escapes in POSIX shells.
    const QString punctuation = shell == Shell::PowerShell ? u"-_./:\\"_s : u"-_./:@+=,"_s;
    const bool plain = !text.isEmpty() && std::ranges::all_of(text, [&punctuation](QChar c) {
        return c.unicode() < 128 && (c.isLetterOrNumber() || punctuation.contains(c));
    });
    return plain ? text : quote(text, shell);
}

QString CopyCommands::quote(const QString &text, Shell shell) {
    QString escaped = text;
    if (shell == Shell::PowerShell) {
        escaped.replace(u'\'', u"''"_s);
    } else {
        escaped.replace(u'\'', u"'\\''"_s);
    }
    return u"'"_s + escaped + u"'"_s;
}

std::optional<QString> CopyCommands::policyCheck(const Action &action, Shell shell) {
    QString kind;
    switch (action.kind) {
    case Action::Kind::Shell: break;
    case Action::Kind::FsRead: kind = u"fs-read"_s; break;
    case Action::Kind::FsWrite: kind = u"fs-write"_s; break;
    case Action::Kind::Net: kind = u"net"_s; break;
    case Action::Kind::Fetch: kind = u"fetch"_s; break;
    case Action::Kind::McpTool: kind = u"mcp"_s; break;
    default: return std::nullopt;
    }
    QString line = u"openmoat policy check "_s + quote(action.target, shell);
    if (!kind.isEmpty()) {
        line += u" --kind "_s + kind;
    }
    return line;
}

QString McpNotices::title() {
    return u"MCP server changes wait for you"_s;
}

QString McpNotices::note() {
    return u"OpenMoat refuses a changed server's tool calls until you accept it. "
           u"openmoat mcp accept shows each change and asks."_s;
}

std::optional<QString> McpNotices::server(const QString &line) {
    constexpr QStringView prefix = u"MCP server `";
    if (!line.startsWith(prefix)) {
        return std::nullopt;
    }
    const qsizetype end = line.indexOf(u'`', prefix.size());
    if (end <= prefix.size()) {
        return std::nullopt;
    }
    return line.mid(prefix.size(), end - prefix.size());
}

QStringList McpNotices::servers(const QStringList &lines) {
    QStringList out;
    for (const QString &line : lines) {
        if (const auto name = server(line); name && !out.contains(*name)) {
            out.append(*name);
        }
    }
    return out;
}

QStringList McpNotices::acceptCommands(const QStringList &lines, Shell shell) {
    const QStringList names = servers(lines);
    if (names.isEmpty()) {
        return {CopyCommands::mcpAccept(std::nullopt, shell)};
    }
    QStringList out;
    for (const QString &name : names) {
        out.append(CopyCommands::mcpAccept(name, shell));
    }
    return out;
}

QUrl DocsLink::home() { return QUrl(u"https://openmoat.dev"_s); }
QUrl DocsLink::blocked() { return QUrl(u"https://openmoat.dev/docs/blocked/"_s); }
QUrl DocsLink::checkACommand() { return QUrl(u"https://openmoat.dev/docs/check-a-command/"_s); }
QUrl DocsLink::quickstart() { return QUrl(u"https://openmoat.dev/docs/quickstart/"_s); }
QUrl DocsLink::limits() { return QUrl(u"https://openmoat.dev/docs/limits/"_s); }
QUrl DocsLink::turnOff() { return QUrl(u"https://openmoat.dev/docs/turn-off/"_s); }

QUrl DocsLink::reportWrongBlock(const std::optional<QString> &rule) {
    QUrl url(u"https://github.com/crocodile-labs/openmoat/issues/new"_s);
    QUrlQuery query;
    query.addQueryItem(u"title"_s, u"False positive: "_s + rule.value_or(u"a blocked call"_s));
    url.setQuery(query);
    return url;
}

} // namespace moatbar
