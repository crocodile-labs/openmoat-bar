#include "Fixtures.hpp"
#include "core/IconState.hpp"
#include "core/Json.hpp"
#include "core/SecurityChecks.hpp"
#include "core/Text.hpp"

#include <QTimeZone>

#include <algorithm>

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

namespace {

Snapshot makeSnapshot(const QString &status, std::optional<ProxyState> proxy = std::nullopt) {
    return Snapshot{
        json::parseStatus(fixture(status)).value(),
        json::parseEvents(fixture(u"show-today"_s)).value(),
        std::move(proxy),
        u"0.5.3"_s,
        QDateTime::fromMSecsSinceEpoch(1792061000000),
    };
}

QStringList ids(const std::vector<Event> &events) {
    QStringList out;
    for (const Event &event : events) {
        out << event.id;
    }
    return out;
}

} // namespace

class TestSnapshot : public QObject {
    Q_OBJECT

private slots:
    void countsCoverEveryVerdict() {
        const VerdictCounts counts = makeSnapshot(u"status"_s).counts();
        QCOMPARE(counts[Verdict::Deny], 3);
        QCOMPARE(counts[Verdict::Ask], 1);
        QCOMPARE(counts[Verdict::Deferred], 1);
        QCOMPARE(counts[Verdict::Allow], 3);
        QCOMPARE(counts.total(), 8);
    }

    void countsForOneAgent() {
        const VerdictCounts counts = makeSnapshot(u"status"_s).counts(u"codex");
        QCOMPARE(counts[Verdict::Deny], 1);
        QCOMPARE(counts[Verdict::Deferred], 1);
        QCOMPARE(counts[Verdict::Allow], 0);
    }

    void listIsNewestFirst() {
        QCOMPARE(ids(makeSnapshot(u"status"_s).list(Verdict::Deny)), (QStringList{u"1e"_s, u"1c"_s, u"1b"_s}));
    }

    void hourlyBucketsByLocalHour() {
        // 1792054800000 ms is 09:00 UTC; the fixture runs from 09:00 to 10:40.
        const auto hours = makeSnapshot(u"status"_s).hourly({}, QTimeZone::utc());
        QCOMPARE(hours[9][Verdict::Allow], 1);
        QCOMPARE(hours[9][Verdict::Deny], 2);
        QCOMPARE(hours[10][Verdict::Deny], 1);
        QCOMPARE(hours[10][Verdict::Allow], 2);
        QCOMPARE(hours[11].total(), 0);
    }

    void sessionsGroupAndSortByLastActivity() {
        const auto sessions = makeSnapshot(u"status"_s).sessions();
        QStringList order;
        for (const Session &session : sessions) {
            order << session.id;
        }
        QCOMPARE(order, (QStringList{u"s-cur"_s, u"s-moat"_s, u"s-app"_s, u"s-site"_s}));
        QCOMPARE(sessions[1].counts.total(), 3);
        QCOMPARE(sessions[1].cwd.value_or(QString{}), u"/Users/you/code/openmoat"_s);
    }

    void topRulesCountOnlyBlocksAndAsks() {
        const auto rules = makeSnapshot(u"status"_s).topRules();
        QCOMPARE(rules.size(), std::size_t{3});
        QVERIFY(rules[0] == (RuleCount{u"secrets-paths"_s, 2}));
        QVERIFY(rules[1] == (RuleCount{u"destructive"_s, 1}));
        QVERIFY(rules[2] == (RuleCount{u"git-internals"_s, 1}));
    }

    void agentsProtectedAndUnprotected() {
        const Snapshot fine = makeSnapshot(u"status"_s);
        QCOMPARE(fine.protectedCount(), 2);
        QCOMPARE(fine.installedAgents().size(), std::size_t{2});
        QVERIFY(fine.unprotected().empty());
        QCOMPARE(makeSnapshot(u"status-unprotected"_s).unprotected().front().host, u"claude-code"_s);
    }

    void agentNameCoversEveryHost() {
        const Snapshot snapshot{
            json::parseStatus(fixture(u"status-hosts"_s)).value(),
            json::parseEvents(fixture(u"show-hosts"_s)).value(),
            std::nullopt,
            u"0.9.0"_s,
            QDateTime::fromMSecsSinceEpoch(1792061000000),
        };
        QStringList names;
        for (const Event &event : snapshot.events) {
            names << snapshot.agentName(event.host);
        }
        QCOMPARE(names, (QStringList{u"Gemini CLI"_s, u"Network proxy"_s, u"MCP proxy"_s, u"openmoat run"_s}));
        QCOMPARE(snapshot.agentName(u"a-host-from-the-future"_s), u"a-host-from-the-future"_s);
        QCOMPARE(snapshot.unprotected().size(), std::size_t{1});
        QCOMPARE(snapshot.unprotected().front().host, u"gemini-cli"_s);
        QVERIFY(snapshot.agent(u"gemini-cli")->reason.value_or(QString{}).startsWith(u"hook turned off by"_s));
        QCOMPARE(snapshot.protectedCount(), 3);
        QCOMPARE(HostText::shortName(u"GitHub Copilot CLI"_s), u"Copilot"_s);
        QCOMPARE(HostText::shortName(u"pi"_s), u"pi"_s);
    }

    void iconPriority() {
        const Snapshot fine = makeSnapshot(u"status"_s);
        const Snapshot broken = makeSnapshot(u"status-unprotected"_s);
        QVERIFY(decideIcon(nullptr, std::nullopt) == IconState::Unavailable);
        QVERIFY(decideIcon(&broken, std::nullopt, true) == IconState::Unprotected);
        QVERIFY(decideIcon(&fine, std::nullopt, true) == IconState::Attention);
        QVERIFY(decideIcon(&fine, 1792056000000) == IconState::NewBlocks);
        QVERIFY(decideIcon(&fine, 1792059000000) == IconState::Quiet);
    }

    void lockDriftIsAProblemAndAPolicyUpdateIsInfo() {
        const auto checks = securityChecks(makeSnapshot(u"status-notices"_s));
        const auto lock = std::ranges::find(checks, u"lock"_s, &SecurityCheck::id);
        QVERIFY(lock != checks.end());
        QVERIFY(lock->kind == SecurityCheck::Kind::Problem);
        QCOMPARE(lock->fix.value_or(QString{}), u"openmoat doctor"_s);
        const auto update = std::ranges::find(checks, u"policy-update"_s, &SecurityCheck::id);
        QVERIFY(update != checks.end());
        QVERIFY(update->kind == SecurityCheck::Kind::Info);
        QCOMPARE(update->fix.value_or(QString{}), u"openmoat policy upgrade"_s);
        const auto attention = needingAttention(checks);
        QCOMPARE(attention.size(), std::size_t{1});
        QCOMPARE(attention.front().id, u"lock"_s);
    }

    void projectSettingsNeedALook() {
        const auto checks = securityChecks(makeSnapshot(u"status-project-settings"_s));
        const auto settings = std::ranges::find(checks, u"project-settings"_s, &SecurityCheck::id);
        QVERIFY(settings != checks.end());
        QVERIFY(settings->kind == SecurityCheck::Kind::Warning);
        QCOMPARE(settings->title, u"Project settings need a look"_s);
        QCOMPARE(settings->detail.value_or(QString{}).split(u'\n').size(), 2);
        QCOMPARE(settings->fix.value_or(QString{}), u"openmoat doctor"_s);
        const auto attention = needingAttention(checks);
        QCOMPARE(attention.size(), std::size_t{1});
        QCOMPARE(attention.front().id, u"project-settings"_s);
    }

    void mcpChangesNeedALook() {
        const auto checks = securityChecks(makeSnapshot(u"status-mcp"_s));
        const auto mcp = std::ranges::find(checks, u"mcp"_s, &SecurityCheck::id);
        QVERIFY(mcp != checks.end());
        QVERIFY(mcp->kind == SecurityCheck::Kind::Warning);
        // Two servers: the command that shows every change.
        QCOMPARE(mcp->fix.value_or(QString{}), u"openmoat mcp accept"_s);
        QVERIFY(mcp->detail.value_or(QString{}).contains(u"MCP server `gh`"_s));
        const auto attention = needingAttention(checks);
        QCOMPARE(attention.size(), std::size_t{1});
        QCOMPARE(attention.front().id, u"mcp"_s);

        Snapshot one = makeSnapshot(u"status"_s);
        one.status.mcpChanges = QStringList{u"MCP server `gh` in /x changed"_s};
        const auto single = securityChecks(one);
        const auto gh = std::ranges::find(single, u"mcp"_s, &SecurityCheck::id);
        QVERIFY(gh != single.end());
        QCOMPARE(gh->fix.value_or(QString{}), u"openmoat mcp accept gh"_s);

        // An older moat sends no mcp_changes: no check at all.
        for (const QString &name : {u"status"_s, u"status-notices"_s}) {
            const auto older = securityChecks(makeSnapshot(name));
            QVERIFY(std::ranges::find(older, u"mcp"_s, &SecurityCheck::id) == older.end());
        }
    }

    void securityChecksWorstFirst() {
        const auto checks =
            securityChecks(makeSnapshot(u"status"_s, ProxyState{ProxyState::Kind::Stopped, {}}));
        QStringList order;
        for (const SecurityCheck &check : checks) {
            order << check.id;
        }
        QCOMPARE(order, (QStringList{u"proxy"_s, u"agent-codex"_s, u"moat"_s, u"agent-claude-code"_s}));
        QCOMPARE(needingAttention(checks).size(), std::size_t{1});
        // Hook only is shown but does not turn the icon amber.
        QVERIFY(needingAttention(securityChecks(makeSnapshot(u"status"_s))).empty());
    }

    void copyCommandsQuoteForEachShell() {
        const Action read{Action::Kind::FsRead, u"~/.ssh/id_ed25519"_s, {}, {}, u"fs_read"_s};
        QCOMPARE(CopyCommands::policyCheck(read, Shell::Posix).value_or(QString{}),
                 u"openmoat policy check '~/.ssh/id_ed25519' --kind fs-read"_s);
        QCOMPARE(CopyCommands::quote(u"it's"_s, Shell::Posix), u"'it'\\''s'"_s);
        QCOMPARE(CopyCommands::quote(u"it's"_s, Shell::PowerShell), u"'it''s'"_s);
        const Action patch{Action::Kind::Patch, {}, {}, {u"a"_s}, u"patch"_s};
        QVERIFY(!CopyCommands::policyCheck(patch).has_value());
    }

    void lostProtectionIsReportedOnce() {
        const Snapshot fine = makeSnapshot(u"status"_s);
        const Snapshot broken = makeSnapshot(u"status-unprotected"_s);
        QCOMPARE(newlyUnprotected(nullptr, broken).front().host, u"claude-code"_s);
        QCOMPARE(newlyUnprotected(&fine, broken).size(), std::size_t{1});
        QVERIFY(newlyUnprotected(&broken, broken).empty());
        QVERIFY(newlyUnprotected(&broken, fine).empty()); // a fix is not a notification
    }

    void moatHomeFollowsTheVariable() {
        QCOMPARE(moatHome({}, u"/home/you"_s), u"/home/you/.moat"_s);
        QCOMPARE(moatHome(u"/tmp/m/"_s, u"/home/you"_s), u"/tmp/m"_s);
    }

    void reportLinkCarriesOnlyTheRule() {
        const QUrl url = DocsLink::reportWrongBlock(u"secrets-paths"_s);
        QCOMPARE(url.host(), u"github.com"_s);
        QCOMPARE(url.query(QUrl::FullyDecoded), u"title=False positive: secrets-paths"_s);
    }
};

QTEST_GUILESS_MAIN(TestSnapshot)
#include "tst_snapshot.moc"
