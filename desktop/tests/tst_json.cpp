#include "Fixtures.hpp"
#include "core/Json.hpp"
#include "core/Text.hpp"

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

class TestJson : public QObject {
    Q_OBJECT

private slots:
    void statusDecodesEveryLevel() {
        const auto status = json::parseStatus(fixture(u"status"_s));
        QVERIFY(status.ok());
        const auto &agents = status.value().agents;
        QCOMPARE(agents.size(), std::size_t{3});
        QCOMPARE(agents[0].host, u"claude-code"_s);
        QVERIFY(agents[0].level == Level::HookAndOsSandbox);
        QVERIFY(agents[1].level == Level::HookOnly);
        QVERIFY(agents[2].level == Level::NotFound);
        QCOMPARE(agents[1].reason.value_or(QString{}), u"the sandbox profile is older than the policy"_s);
        QVERIFY(!agents[0].reason.has_value());
    }

    void unknownLevelIsNeverProtected() {
        const auto status = json::parseStatus(fixture(u"status-unprotected"_s));
        QVERIFY(status.ok());
        QVERIFY(status.value().agents[2].level == Level::Unknown);
        QVERIFY(!isHooked(status.value().agents[2].level));
    }

    void eventsDecodeActionsVerdictsAndIds() {
        const auto events = json::parseEvents(fixture(u"show-today"_s));
        QVERIFY(events.ok());
        const auto &list = events.value();
        QCOMPARE(list.size(), std::size_t{8});
        QCOMPARE(list[0].id, u"1a"_s);
        QCOMPARE(list[0].action->shellCommand().value_or(QString{}), u"git status --short"_s);
        QVERIFY(list[2].action->kind == Action::Kind::FsRead);
        QCOMPARE(list[2].display(), u"Read /Users/you/.ssh/id_ed25519"_s);
        QVERIFY(list[3].verdict == Verdict::Deferred);
        QCOMPARE(list[4].rule().value_or(QString{}), u"secrets-paths"_s);
        QCOMPARE(list[4].reason().value_or(QString{}), u"secret material: read /Users/you/code/app/.env"_s);
        QVERIFY(list[6].action->kind == Action::Kind::McpTool);
    }

    void eventWithoutActionShowsTheTool() {
        const auto events = json::parseEvents(fixture(u"show-today"_s));
        QVERIFY(events.ok());
        const Event &event = events.value()[7];
        QVERIFY(!event.action.has_value());
        QVERIFY(!event.cwd.has_value());
        QCOMPARE(event.display(), u"TodoWrite"_s);
    }

    void olderAndNewerMoatStillDecode() {
        const auto events = json::parseEvents(fixture(u"show-legacy"_s));
        QVERIFY(events.ok());
        const auto &list = events.value();
        QCOMPARE(list[0].id, u"1f"_s); // integer row ids become hex
        QVERIFY(list[0].verdict == Verdict::Deferred); // never counted as allowed or blocked
        QCOMPARE(list[0].display(), u"Patch 2 files"_s);
        QVERIFY(list[0].reasons.isEmpty());
        QVERIFY(list[1].action->kind == Action::Kind::Other);
        QCOMPARE(list[1].display(), u"frobnicate"_s);
    }

    void reportDecodesRuleTuples() {
        const auto report = json::parseSummary(fixture(u"report-7d"_s));
        QVERIFY(report.ok());
        const Summary &summary = report.value();
        QCOMPARE(summary.total, 8421);
        QCOMPARE(summary.deferred, 1350);
        QCOMPARE(summary.byHost.at(u"codex"_s), 3301);
        QVERIFY(summary.topRules.front() == (RuleCount{u"secrets-paths"_s, 22}));
        QCOMPARE(summary.activeHours, 41);
    }

    void proxyDecodesKnownAndUnknownStates() {
        const auto running = json::parseProxy(fixture(u"proxy-running"_s));
        QVERIFY(running.ok() && running.value().running());
        const auto unknown = json::parseProxy(fixture(u"proxy-unknown"_s));
        QVERIFY(unknown.ok());
        QVERIFY(unknown.value().kind == ProxyState::Kind::Unknown);
        QCOMPARE(unknown.value().label(), u"systemctl --user has no user bus"_s);
    }

    void allowedDecodesRulesGrantsAndRepos() {
        const auto allowed = json::parseAllowed(fixture(u"allowed"_s));
        QVERIFY(allowed.ok());
        const AllowedReport &report = allowed.value();
        QCOMPARE(report.rules.size(), std::size_t{3});
        QCOMPARE(report.rules[0].id, u"approved-1"_s);
        QVERIFY(report.rules[0].patterns == (std::vector<RulePatterns>{{u"shell"_s, {u"npm install"_s}}}));
        QCOMPARE(report.rules[1].reason.value_or(QString{}), u"allowed with moat allow --site"_s);
        QCOMPARE(report.rules[1].patterns.size(), std::size_t{2});
        QCOMPARE(report.rules[1].patterns[0].line(), u"Network: docs.rs, *.docs.rs"_s);
        QCOMPARE(report.rules[1].patterns[1].kind, u"fetch"_s);
        QCOMPARE(report.rules[2].patterns[2].label(), u"MCP tools"_s);
        QCOMPARE(report.sessionGrants.size(), std::size_t{2});
        QCOMPARE(report.sessionGrants[0].what, u"run \"cargo publish --dry-run\""_s);
        QCOMPARE(report.sessionGrants[0].expiresAtMs, std::int64_t{1792072400000});
        QCOMPARE(report.trustedRepos.size(), std::size_t{1});
        QCOMPARE(report.trustedRepos[0].root, u"/Users/you/code/team app"_s);
    }

    void secretsDecodeSourcesAndExposure() {
        const auto list = json::parseSecrets(fixture(u"secret-list"_s));
        QVERIFY(list.ok());
        const auto &secrets = list.value().secrets;
        QCOMPARE(secrets.size(), std::size_t{4});
        QVERIFY(secrets[0].source.kind == SecretSource::Kind::Env);
        QVERIFY(secrets[0].sourceExposed);
        QCOMPARE(secrets[0].line(), u"api.github.com, Authorization header, from the variable GITHUB_TOKEN"_s);
        QVERIFY(secrets[1].source.kind == SecretSource::Kind::File);
        QVERIFY(!secrets[1].sourceExposed);
        QVERIFY(secrets[2].source.kind == SecretSource::Kind::Keychain);
        QCOMPARE(secrets[2].source.account, u"you"_s);
        QVERIFY(secrets[2].plainHttp);
        QVERIFY(secrets[3].source.kind == SecretSource::Kind::Unknown); // a source a newer moat added
    }

    void secretWithoutSourceExposedCountsAsExposed() {
        const auto list = json::parseSecrets(
            QByteArrayLiteral(R"({"secrets": [{"id": "a", "host": "h", "header": "X", "source": {"env": "A"}}]})"));
        QVERIFY(list.ok());
        QVERIFY(list.value().secrets[0].sourceExposed);
    }

    void doctorGroupsByStatusWorstFirst() {
        const auto doctor = json::parseDoctor(fixture(u"doctor"_s));
        QVERIFY(doctor.ok());
        const DoctorReport &report = doctor.value();
        QVERIFY(!report.healthy);
        QCOMPARE(report.problems, 1);
        QCOMPARE(report.checks.size(), std::size_t{7});
        QVERIFY(report.checks[6].status == DoctorStatus::Warning); // unknown status: never fine
        const auto groups = report.groups();
        QCOMPARE(groups.size(), std::size_t{4});
        QVERIFY(groups[0].status == DoctorStatus::Problem);
        QCOMPARE(groups[0].checks.size(), std::size_t{1});
        QCOMPARE(groups[1].checks.size(), std::size_t{2});
        QCOMPARE(groups[3].checks.size(), std::size_t{3});
        QCOMPARE(doctorStatusTitle(groups[1].status), u"Needs a look"_s);
        const DoctorCheck &unnamed = report.checks[3];
        QVERIFY(!unnamed.area.has_value());
        QCOMPARE(unnamed.title(), unnamed.detail);
        QVERIFY(unnamed.subtitle().isEmpty());
    }

    void doctorTextIsUnreadable() {
        QVERIFY(!json::parseDoctor(QByteArrayLiteral("policy  ok\n")).ok());
    }

    void statusDecodesUpdateNotices() {
        const auto status = json::parseStatus(fixture(u"status-notices"_s));
        QVERIFY(status.ok());
        QCOMPARE(status.value().policyUpdate.value_or(QString{}), u"3 changes from the OpenMoat 0.5.7 default"_s);
        QCOMPARE(status.value().lockDrift.size(), 2);
        QVERIFY(status.value().hasUpdateNotices);
        QVERIFY(!MoatRequirement::updateNoticesNote(true).has_value());
    }

    void statusFromOlderMoatHasNoNotices() {
        const auto status = json::parseStatus(fixture(u"status"_s));
        QVERIFY(status.ok());
        QVERIFY(!status.value().policyUpdate.has_value());
        QVERIFY(status.value().lockDrift.isEmpty());
        QVERIFY(!status.value().hasUpdateNotices);
        QCOMPARE(MoatRequirement::updateNoticesNote(false).value_or(QString{}),
                 u"Policy update and changed-file notices need OpenMoat 0.5.7 or later."_s);
        const auto empty = json::parseStatus(QByteArrayLiteral(R"({"agents": [], "policy_update": null, "lock_drift": []})"));
        QVERIFY(empty.ok() && empty.value().hasUpdateNotices && !empty.value().policyUpdate);
    }

    void detailWordsAndCommands() {
        const std::int64_t now = 1792061000000;
        QCOMPARE(DetailsText::endsIn(now + 11400000, now), u"Ends in 3 h 10 min"_s);
        QCOMPARE(DetailsText::endsIn(now + 7200000, now), u"Ends in 2 h"_s);
        QCOMPARE(DetailsText::endsIn(now + 30000, now), u"Ends in 1 min"_s);
        QCOMPARE(DetailsText::endsIn(now - 1, now), u"Ended"_s);
        QCOMPARE(CopyCommands::removeRule(u"approved-1"_s, Shell::Posix), u"moat allow --remove approved-1"_s);
        QCOMPARE(CopyCommands::revokeTrust(u"/Users/you/code/team app"_s, Shell::Posix),
                 u"moat trust --revoke '/Users/you/code/team app'"_s);
        QCOMPARE(CopyCommands::revokeTrust(u"C:\\Users\\you\\code\\app"_s, Shell::PowerShell),
                 u"moat trust --revoke C:\\Users\\you\\code\\app"_s);
        QCOMPARE(CopyCommands::policyUpgrade(), u"moat policy upgrade"_s);
    }

    void textInsteadOfJsonIsUnreadable() {
        const auto status = json::parseStatus(QByteArrayLiteral("Claude Code: hook + OS sandbox\n"));
        QVERIFY(!status.ok());
        QVERIFY(status.error() == (MoatError{MoatError::Kind::Unreadable, u"status"_s, {}}));
    }

    void versionTakesTheSecondWord() {
        QCOMPARE(json::parseVersion(QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n")).value(), u"0.5.3"_s);
        QVERIFY(!json::parseVersion(QByteArrayLiteral("moat")).ok());
    }
};

QTEST_GUILESS_MAIN(TestJson)
#include "tst_json.moc"
