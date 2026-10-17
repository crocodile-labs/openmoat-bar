#include "app/EventViews.hpp"
#include "core/Format.hpp"
#include "core/Text.hpp"

#include <QDir>
#include <QFileInfo>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

/// The last folder of a working directory: `openmoat` for `~/code/openmoat`.
QString folderName(const std::optional<QString> &cwd) {
    if (!cwd || cwd->isEmpty()) {
        return {};
    }
    const QString name = QFileInfo(QDir::cleanPath(*cwd)).fileName();
    return name.isEmpty() ? *cwd : name;
}

bool isCommand(const Event &event) {
    return event.action && event.action->shellCommand().has_value();
}

} // namespace

QString verdictKey(Verdict verdict) {
    switch (verdict) {
    case Verdict::Deny: return u"deny"_s;
    case Verdict::Ask: return u"ask"_s;
    case Verdict::Deferred: return u"deferred"_s;
    case Verdict::Allow: return u"allow"_s;
    }
    return {};
}

std::optional<Verdict> verdictFromKey(QStringView key) {
    for (const Verdict verdict : kVerdicts) {
        if (verdictKey(verdict) == key) {
            return verdict;
        }
    }
    return std::nullopt;
}

QVariantMap eventRowMap(const Event &event, const QString &agentName) {
    return {
        {u"id"_s, event.id},
        {u"display"_s, Format::oneLine(event.display(), 80)},
        {u"monospace"_s, isCommand(event)},
        {u"rule"_s, event.rule().value_or(QString{})},
        {u"agent"_s, agentName},
        {u"host"_s, event.host},
        {u"place"_s, folderName(event.cwd)},
        {u"time"_s, Format::clock(event.time())},
        {u"verdict"_s, verdictKey(event.verdict)},
        {u"verdictTitle"_s, verdictTitle(event.verdict)},
    };
}

QVariantMap decisionMap(const Event &event, const QString &agentName) {
    const auto rule = event.rule();
    const auto why = rule ? RuleText::why(*rule) : std::nullopt;
    const auto check = event.action ? CopyCommands::policyCheck(*event.action) : std::nullopt;
    return {
        {u"id"_s, event.id},
        {u"verdict"_s, verdictKey(event.verdict)},
        {u"title"_s, verdictTitle(event.verdict)},
        {u"rule"_s, rule.value_or(QString{})},
        {u"agent"_s, agentName},
        {u"host"_s, event.host},
        {u"time"_s, Format::clock(event.time())},
        {u"tool"_s, event.tool},
        {u"display"_s, event.display()},
        {u"monospace"_s, isCommand(event)},
        {u"folder"_s, event.cwd ? Format::shortPath(*event.cwd, QDir::homePath()) : QString{}},
        {u"told"_s, event.reason().value_or(QString{})},
        {u"why"_s, why.value_or(QString{})},
        {u"checkCommand"_s, check.value_or(QString{})},
        {u"blocked"_s, event.verdict == Verdict::Deny || event.verdict == Verdict::Ask},
    };
}

} // namespace moatbar
