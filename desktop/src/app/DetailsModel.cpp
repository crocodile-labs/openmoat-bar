#include "app/DetailsModel.hpp"
#include "core/Text.hpp"

#include <QCoreApplication>
#include <QPointer>
#include <QThreadPool>

#include <memory>

using namespace Qt::StringLiterals;
using namespace std::chrono_literals;

namespace moatbar {
namespace {

/// `openmoat doctor` checks every sandbox, which can take a few seconds.
constexpr auto kReadTimeout = 15s;

Result<Details> readDetails() {
    const auto binary = MoatClient::locate();
    if (!binary) {
        return MoatError{MoatError::Kind::NotInstalled, {}, {}};
    }
    return MoatClient(*binary, std::make_shared<ProcessRunner>(), kReadTimeout).details();
}

/// `state` and `note` for a screen that has no value.
template <typename T>
std::optional<QVariantMap> notLoaded(const Screen<T> &screen) {
    if (screen.needsNewerMoat) {
        return QVariantMap{{u"state"_s, u"note"_s}, {u"note"_s, *screen.needsNewerMoat}};
    }
    if (screen.failed) {
        return QVariantMap{{u"state"_s, u"failed"_s},
                           {u"note"_s, QString(*screen.failed + u". openmoat doctor shows what is wrong."_s)}};
    }
    if (!screen.value) {
        return QVariantMap{{u"state"_s, u"loading"_s}, {u"note"_s, u"Reading OpenMoat…"_s}};
    }
    return std::nullopt;
}

} // namespace

DetailsModel::DetailsModel(QObject *parent) : QObject(parent), m_now(QDateTime::currentDateTime()) {}

void DetailsModel::setData(Details details, const QDateTime &now) {
    ++m_generation; // a read still running must not replace this
    m_loading = false;
    m_error.reset();
    m_details = std::move(details);
    m_now = now;
    ++m_revision;
    emit changed();
}

void DetailsModel::setStatus(const StatusReport &status) {
    m_agentNames.clear();
    for (const Protection &agent : status.agents) {
        m_agentNames.insert(agent.host, agent.name);
    }
    m_updateNote = MoatRequirement::updateNoticesNote(status.hasUpdateNotices).value_or(QString{});
    ++m_revision;
    emit changed();
}

void DetailsModel::load() {
    const int generation = ++m_generation;
    m_loading = true;
    ++m_revision;
    emit changed();
    QThreadPool::globalInstance()->start([guard = QPointer<DetailsModel>(this), generation] {
        auto result = std::make_shared<Result<Details>>(readDetails());
        QMetaObject::invokeMethod(
            QCoreApplication::instance(),
            [guard, result, generation] {
                if (guard) {
                    guard->apply(std::move(*result), generation);
                }
            },
            Qt::QueuedConnection);
    });
}

void DetailsModel::apply(Result<Details> result, int generation) {
    if (generation != m_generation) {
        return;
    }
    m_loading = false;
    m_now = QDateTime::currentDateTime();
    if (result) {
        m_details = std::move(result).value();
        m_error.reset();
    } else {
        m_error = result.error().message();
    }
    ++m_revision;
    emit changed();
}

// MARK: - Pages

QVariantMap DetailsModel::allowed() const {
    if (m_error) {
        return {{u"state"_s, u"failed"_s}, {u"note"_s, *m_error}};
    }
    if (!m_details) {
        return {{u"state"_s, u"loading"_s}, {u"note"_s, u"Reading OpenMoat…"_s}};
    }
    if (auto other = notLoaded(m_details->allowed)) {
        return *other;
    }
    const AllowedReport &report = *m_details->allowed.value;
    QVariantList rules;
    for (const AllowedRule &rule : report.rules) {
        QStringList lines;
        if (rule.reason) {
            lines << *rule.reason;
        }
        for (const RulePatterns &patterns : rule.patterns) {
            lines << patterns.line();
        }
        rules << QVariantMap{
            {u"title"_s, rule.id},
            {u"detail"_s, lines.join(u'\n')},
            {u"command"_s, CopyCommands::removeRule(rule.id)},
        };
    }
    QVariantList grants;
    for (const SessionGrant &grant : report.sessionGrants) {
        const QString agent = m_agentNames.value(grant.host, HostText::otherName(grant.host));
        grants << QVariantMap{
            {u"title"_s, grant.what},
            {u"detail"_s, DetailsText::grantLine(grant, agent, m_now.toMSecsSinceEpoch())},
        };
    }
    QVariantList repos;
    for (const TrustedRepo &repo : report.trustedRepos) {
        repos << QVariantMap{
            {u"title"_s, repo.root},
            {u"detail"_s, u"Policy file sha256 %1. A change to it ends the trust."_s.arg(
                              DetailsText::shortHash(repo.sha256))},
            {u"command"_s, CopyCommands::revokeTrust(repo.root)},
        };
    }
    return {
        {u"state"_s, u"loaded"_s},
        {u"note"_s, QString{}},
        {u"rules"_s, rules},
        {u"grants"_s, grants},
        {u"repos"_s, repos},
    };
}

QVariantMap DetailsModel::secrets() const {
    if (m_error) {
        return {{u"state"_s, u"failed"_s}, {u"note"_s, *m_error}};
    }
    if (!m_details) {
        return {{u"state"_s, u"loading"_s}, {u"note"_s, u"Reading OpenMoat…"_s}};
    }
    if (auto other = notLoaded(m_details->secrets)) {
        return *other;
    }
    QVariantList items;
    int exposed = 0;
    for (const BrokeredSecret &secret : m_details->secrets.value->secrets) {
        exposed += secret.sourceExposed ? 1 : 0;
        QString hint = secret.sourceExposed ? DetailsText::exposedHint() : DetailsText::coveredHint();
        if (secret.plainHttp) {
            hint += u" "_s + DetailsText::plainHttpHint(secret);
        }
        items << QVariantMap{
            {u"id"_s, secret.id},
            {u"host"_s, secret.host},
            {u"line"_s, secret.line()},
            {u"hint"_s, hint},
            {u"tone"_s, secret.sourceExposed ? u"warn"_s : u"ok"_s},
            {u"command"_s, secret.sourceExposed ? DetailsText::lint() : QString{}},
        };
    }
    return {
        {u"state"_s, u"loaded"_s},
        {u"note"_s, QString{}},
        {u"items"_s, items},
        {u"hint"_s, exposed > 0 ? u"%1 readable by the agent"_s.arg(exposed) : QString{}},
    };
}

QVariantMap DetailsModel::checks() const {
    if (m_error) {
        return {{u"state"_s, u"failed"_s}, {u"note"_s, *m_error}};
    }
    if (!m_details) {
        return {{u"state"_s, u"loading"_s}, {u"note"_s, u"Reading OpenMoat…"_s}};
    }
    if (auto other = notLoaded(m_details->checks)) {
        return *other;
    }
    const DoctorReport &report = *m_details->checks.value;
    QVariantList groups;
    for (const DoctorGroup &group : report.groups()) {
        QVariantList items;
        for (const DoctorCheck &check : group.checks) {
            items << QVariantMap{
                {u"title"_s, check.title()},
                {u"subtitle"_s, check.subtitle()},
                {u"topic"_s, doctorTopicLabel(check.topic())},
                {u"hint"_s, CheckText::hint(check).value_or(QString{})},
                {u"command"_s, CheckText::fix(check).value_or(QString{})},
            };
        }
        groups << QVariantMap{
            {u"title"_s, doctorStatusTitle(group.status)},
            {u"tone"_s, doctorStatusTone(group.status)},
            {u"count"_s, static_cast<int>(group.checks.size())},
            {u"items"_s, items},
        };
    }
    return {
        {u"state"_s, u"loaded"_s},
        {u"note"_s, QString{}},
        {u"summary"_s, report.problems == 0 ? u"No problems"_s : u"%1 to fix"_s.arg(report.problems)},
        {u"tone"_s, report.problems == 0 ? u"ok"_s : u"bad"_s},
        {u"groups"_s, groups},
        {u"command"_s, CopyCommands::doctor()},
    };
}

} // namespace moatbar
