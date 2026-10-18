#include "core/Text.hpp"

#include <QUrlQuery>

#include <algorithm>

using namespace Qt::StringLiterals;

namespace moatbar {

std::optional<QString> RuleText::why(QStringView rule) {
    if (rule == u"secrets-paths") {
        return u"Private keys, .env files and cloud credentials hold passwords and tokens. Agents never read them."_s;
    }
    if (rule == u"destructive") {
        return u"This throws away work that can't be brought back, like uncommitted changes or a home folder."_s;
    }
    if (rule == u"pipe-to-shell") {
        return u"Running a script straight from the internet means running code nobody has looked at."_s;
    }
    if (rule == u"env-secrets" || rule == u"env-dump") {
        return u"Printing environment variables would show tokens to the agent and to whatever it talks to."_s;
    }
    if (rule == u"shell-rc") {
        return u"Changing your shell's startup files would run code in every terminal you open later."_s;
    }
    if (rule == u"kernel-self") {
        return u"Agents can't change OpenMoat's own rules, hooks or binary. Only a person can, in a terminal."_s;
    }
    if (rule == u"kernel-integrity") {
        return u"A file OpenMoat watches was changed outside moat, so calls stop until a person looks."_s;
    }
    if (rule == u"git-internals") {
        return u"This changes which hooks git runs, which would run code on later git commands."_s;
    }
    if (rule == u"runs-later") {
        return u"This changes something that runs on its own later, like CI settings or editor tasks."_s;
    }
    if (rule == u"default.net") {
        return u"The agent tried to reach a site that isn't on the allowed list."_s;
    }
    if (rule == u"default") {
        return u"No rule covers this, so the agent's own prompt decided."_s;
    }
    if (rule == u"dev-shell") {
        return u"A normal development command, like building or testing."_s;
    }
    if (rule == u"project-fs") {
        return u"Reading or writing files inside the project."_s;
    }
    return std::nullopt;
}

QString CopyCommands::setUp() {
    return u"moat"_s;
}

QString CopyCommands::doctor() {
    return u"moat doctor"_s;
}

QString CopyCommands::install(Shell shell) {
    if (shell == Shell::PowerShell) {
        return u"powershell -ExecutionPolicy Bypass -c \"irm "
               u"https://github.com/crocodile-labs/openmoat/releases/latest/download/openmoat-installer.ps1 | iex\""_s;
    }
    return u"brew install crocodile-labs/tap/moat"_s;
}

QString CopyCommands::policyUpgrade() {
    return u"moat policy upgrade"_s;
}

QString CopyCommands::removeRule(const QString &id, Shell shell) {
    return u"moat allow --remove "_s + quoteIfNeeded(id, shell);
}

QString CopyCommands::revokeTrust(const QString &root, Shell shell) {
    return u"moat trust --revoke "_s + quoteIfNeeded(root, shell);
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
    QString line = u"moat policy check "_s + quote(action.target, shell);
    if (!kind.isEmpty()) {
        line += u" --kind "_s + kind;
    }
    return line;
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
