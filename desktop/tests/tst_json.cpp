#include "Fixtures.hpp"
#include "core/Json.hpp"

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
