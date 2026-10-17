#include "core/Json.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>

using namespace Qt::StringLiterals;

namespace moatbar::json {
namespace {

MoatError unreadable(const QString &command) {
    return MoatError{MoatError::Kind::Unreadable, command, {}};
}

std::optional<QJsonDocument> parse(const QByteArray &bytes) {
    QJsonParseError error{};
    QJsonDocument document = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError) {
        return std::nullopt;
    }
    return document;
}

std::optional<QString> optionalString(const QJsonObject &object, QStringView key) {
    const QJsonValue value = object.value(key);
    if (!value.isString()) {
        return std::nullopt;
    }
    return value.toString();
}

QStringList stringList(const QJsonValue &value) {
    QStringList out;
    const QJsonArray array = value.toArray();
    out.reserve(array.size());
    for (const QJsonValue &item : array) {
        if (item.isString()) {
            out.append(item.toString());
        }
    }
    return out;
}

/// `{"shell": {"command": "ls"}}` and friends. Anything unknown keeps its tag.
std::optional<Action> parseAction(const QJsonValue &value) {
    if (!value.isObject()) {
        return std::nullopt;
    }
    const QJsonObject outer = value.toObject();
    if (outer.isEmpty()) {
        return std::nullopt;
    }
    const QString tag = outer.begin().key();
    const QJsonObject fields = outer.begin().value().toObject();
    const auto field = [&fields](QStringView key) { return fields.value(key).toString(); };

    Action action;
    action.wireKind = tag;
    if (tag == u"shell") {
        action.kind = Action::Kind::Shell;
        action.target = field(u"command");
    } else if (tag == u"foreign_shell") {
        action.kind = Action::Kind::ForeignShell;
        action.target = field(u"command");
        action.qualifier = fields.contains(u"shell") ? field(u"shell") : u"shell"_s;
    } else if (tag == u"fs_read") {
        action.kind = Action::Kind::FsRead;
        action.target = field(u"path");
    } else if (tag == u"fs_write") {
        action.kind = Action::Kind::FsWrite;
        action.target = field(u"path");
    } else if (tag == u"net") {
        action.kind = Action::Kind::Net;
        action.target = field(u"url");
    } else if (tag == u"fetch") {
        action.kind = Action::Kind::Fetch;
        action.target = field(u"url");
    } else if (tag == u"web_search") {
        action.kind = Action::Kind::WebSearch;
        action.target = field(u"query");
    } else if (tag == u"unknown_tool") {
        action.kind = Action::Kind::UnknownTool;
        action.target = field(u"tool");
        action.qualifier = field(u"host");
    } else if (tag == u"patch") {
        action.kind = Action::Kind::Patch;
        action.targets = stringList(fields.value(u"writes"));
    } else if (tag == u"read_files") {
        action.kind = Action::Kind::ReadFiles;
        action.targets = stringList(fields.value(u"paths"));
    } else if (tag == u"mcp_tool") {
        action.kind = Action::Kind::McpTool;
        action.target = field(u"name");
    } else {
        action.kind = Action::Kind::Other;
    }
    return action;
}

std::optional<Event> parseEvent(const QJsonObject &object) {
    const QJsonValue id = object.value(u"id");
    const QJsonValue ts = object.value(u"ts_ms");
    const QJsonValue host = object.value(u"host");
    const QJsonValue session = object.value(u"session_id");
    const QJsonValue tool = object.value(u"tool");
    if (!ts.isDouble() || !host.isString() || !session.isString() || !tool.isString()) {
        return std::nullopt;
    }
    Event event;
    // Hex string ("1f"); older moat builds wrote the row number.
    event.id = id.isString() ? id.toString() : QString::number(id.toInteger(), 16);
    event.tsMs = ts.toInteger();
    event.host = host.toString();
    event.sessionId = session.toString();
    event.cwd = optionalString(object, u"cwd");
    event.tool = tool.toString();
    event.action = parseAction(object.value(u"action"));
    event.verdict = verdictFromWire(object.value(u"verdict").toString());
    event.rules = stringList(object.value(u"rules"));
    event.reasons = stringList(object.value(u"reasons"));
    event.raw = object;
    return event;
}

} // namespace

Result<StatusReport> parseStatus(const QByteArray &bytes) {
    const auto document = parse(bytes);
    if (!document || !document->isObject()) {
        return unreadable(u"status"_s);
    }
    StatusReport report;
    const QJsonArray agents = document->object().value(u"agents").toArray();
    report.agents.reserve(static_cast<std::size_t>(agents.size()));
    for (const QJsonValue &value : agents) {
        const QJsonObject object = value.toObject();
        Protection protection;
        protection.host = object.value(u"host").toString();
        protection.name = object.value(u"name").toString();
        protection.level = levelFromWire(object.value(u"level").toString());
        protection.reason = optionalString(object, u"reason");
        protection.gaps = object.value(u"gaps").toString();
        if (!protection.host.isEmpty()) {
            report.agents.push_back(std::move(protection));
        }
    }
    return report;
}

Result<std::vector<Event>> parseEvents(const QByteArray &bytes) {
    const auto document = parse(bytes);
    if (!document || !document->isArray()) {
        return unreadable(u"show"_s);
    }
    const QJsonArray array = document->array();
    std::vector<Event> events;
    events.reserve(static_cast<std::size_t>(array.size()));
    for (const QJsonValue &value : array) {
        if (auto event = parseEvent(value.toObject())) {
            events.push_back(std::move(*event));
        }
    }
    return events;
}

Result<Summary> parseSummary(const QByteArray &bytes) {
    const auto document = parse(bytes);
    if (!document || !document->isObject()) {
        return unreadable(u"report"_s);
    }
    const QJsonObject object = document->object();
    Summary summary;
    summary.sinceMs = object.value(u"since_ms").toInteger();
    summary.total = object.value(u"total").toInt();
    summary.allowed = object.value(u"allowed").toInt();
    summary.deferred = object.value(u"deferred").toInt(); // older moat: absent, 0
    summary.asked = object.value(u"asked").toInt();
    summary.denied = object.value(u"denied").toInt();
    summary.sessions = object.value(u"sessions").toInt();
    summary.activeHours = object.value(u"active_hours").toInt();
    const QJsonObject byHost = object.value(u"by_host").toObject();
    for (auto it = byHost.begin(); it != byHost.end(); ++it) {
        summary.byHost.emplace(it.key(), it.value().toInt());
    }
    // serde writes a (String, u64) tuple as a two-element array.
    for (const QJsonValue &pair : object.value(u"top_rules").toArray()) {
        const QJsonArray tuple = pair.toArray();
        if (tuple.size() == 2) {
            summary.topRules.push_back(RuleCount{tuple.at(0).toString(), tuple.at(1).toInt()});
        }
    }
    return summary;
}

Result<ProxyState> parseProxy(const QByteArray &bytes) {
    const auto document = parse(bytes);
    if (!document || !document->isObject()) {
        return unreadable(u"proxy"_s);
    }
    const QJsonObject state = document->object().value(u"state").toObject();
    const QString wire = state.value(u"state").toString();
    ProxyState proxy;
    if (wire == u"not-installed") {
        proxy.kind = ProxyState::Kind::NotInstalled;
    } else if (wire == u"stopped") {
        proxy.kind = ProxyState::Kind::Stopped;
    } else if (wire == u"running") {
        proxy.kind = ProxyState::Kind::Running;
    } else if (wire == u"drift-blocked") {
        proxy.kind = ProxyState::Kind::DriftBlocked;
    } else if (wire == u"crashlooping") {
        proxy.kind = ProxyState::Kind::Crashlooping;
    } else {
        proxy.kind = ProxyState::Kind::Unknown;
        proxy.details = state.contains(u"details") ? state.value(u"details").toString() : wire;
    }
    return proxy;
}

Result<QString> parseVersion(const QByteArray &bytes) {
    const QStringList words = QString::fromUtf8(bytes).split(u' ', Qt::SkipEmptyParts);
    if (words.size() < 2) {
        return unreadable(u"--version"_s);
    }
    return words.at(1).trimmed();
}

QByteArray toJsonLines(const std::vector<Event> &events) {
    QByteArray out;
    for (const Event &event : events) {
        out += QJsonDocument(event.raw).toJson(QJsonDocument::Compact);
        out += '\n';
    }
    return out;
}

} // namespace moatbar::json
