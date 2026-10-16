#include "Fixtures.hpp"
#include "app/QuickViewModel.hpp"
#include "core/Format.hpp"
#include "core/Json.hpp"

#include <QSignalSpy>

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

namespace {

const QDateTime kNow = QDateTime::fromMSecsSinceEpoch(1792061000000);

Snapshot makeSnapshot(const QString &status) {
    return Snapshot{
        json::parseStatus(fixture(status)).value(),
        json::parseEvents(fixture(u"show-today"_s)).value(),
        std::nullopt,
        u"0.5.3"_s,
        kNow,
    };
}

QStringList column(const QVariantList &rows, const QString &key) {
    QStringList out;
    for (const QVariant &row : rows) {
        out << row.toMap().value(key).toString();
    }
    return out;
}

QVariantMap byKey(const QVariantList &rows, const QString &key, const QString &value) {
    for (const QVariant &row : rows) {
        if (row.toMap().value(key).toString() == value) {
            return row.toMap();
        }
    }
    return {};
}

} // namespace

class TestQuickView : public QObject {
    Q_OBJECT

private slots:
    void overviewMatchesTheMacMenu() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status"_s), std::nullopt, kNow);

        QVERIFY(model.available());
        QVERIFY(model.unavailable().isEmpty());
        QCOMPARE(column(model.tabs(), u"name"_s), (QStringList{u"All"_s, u"Claude Code"_s, u"Codex"_s, u"Cursor"_s}));
        QCOMPARE(byKey(model.tabs(), u"host"_s, u"cursor"_s).value(u"installed"_s).toBool(), false);
        QCOMPARE(model.header().value(u"title"_s).toString(), u"All agents"_s);
        QCOMPARE(model.header().value(u"detail"_s).toString(), u"2 of 2 protected"_s);
        QCOMPARE(model.header().value(u"version"_s).toString(), u"moat 0.5.3"_s);
        QCOMPARE(model.header().value(u"updated"_s).toString(), u"Updated just now"_s);
        QCOMPARE(column(model.verdicts(), u"title"_s),
                 (QStringList{u"Blocked"_s, u"Asked"_s, u"Left to your agent"_s, u"Allowed"_s}));
        QCOMPARE(column(model.verdicts(), u"count"_s), (QStringList{u"3"_s, u"1"_s, u"1"_s, u"3"_s}));
        QVERIFY(model.problems().isEmpty());
        // The All tab lists agents; agentDetail is for one agent's tab.
        QCOMPARE(column(model.agents(), u"host"_s), (QStringList{u"claude-code"_s, u"codex"_s}));
        QVERIFY(model.agentDetail().isEmpty());
        QCOMPARE(model.today().value(u"total"_s).toInt(), 8);
        QCOMPARE(model.today().value(u"hours"_s).toList().size(), 24);
    }

    void aTabShowsOneAgent() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status"_s), std::nullopt, kNow);
        QSignalSpy changed(&model, &QuickViewModel::changed);

        model.setSelectedHost(u"codex"_s);

        QCOMPARE(changed.count(), 1);
        QCOMPARE(model.header().value(u"title"_s).toString(), u"Codex"_s);
        QCOMPARE(model.header().value(u"detail"_s).toString(), u"Hook only"_s);
        QCOMPARE(model.header().value(u"tone"_s).toString(), u"warn"_s);
        QCOMPARE(column(model.verdicts(), u"count"_s), (QStringList{u"1"_s, u"0"_s, u"1"_s, u"0"_s}));
        QCOMPARE(column(model.events(u"deny"_s), u"id"_s), QStringList{u"1e"_s});
        QCOMPARE(model.agentDetail().value(u"name"_s).toString(), u"Codex"_s);
        QCOMPARE(model.today().value(u"total"_s).toInt(), 2);
    }

    void anUnknownTabFallsBackToAll() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status"_s), std::nullopt, kNow);
        model.setSelectedHost(u"codex"_s);
        model.setSelectedHost(u"not-an-agent"_s);
        QCOMPARE(model.selectedHost(), QString{});
        QCOMPARE(model.header().value(u"title"_s).toString(), u"All agents"_s);
    }

    void listsAreNewestFirstAndDecisionsComplete() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status"_s), std::nullopt, kNow);

        const QVariantList blocked = model.events(u"deny"_s);
        QCOMPARE(column(blocked, u"id"_s), (QStringList{u"1e"_s, u"1c"_s, u"1b"_s}));
        QCOMPARE(model.moreEvents(u"deny"_s), 0);
        QVERIFY(model.events(u"not-a-verdict"_s).isEmpty());

        const QVariantMap decision = model.decision(u"1e"_s);
        QCOMPARE(decision.value(u"verdict"_s).toString(), u"deny"_s);
        QCOMPARE(decision.value(u"title"_s).toString(), u"Blocked"_s);
        QCOMPARE(decision.value(u"agent"_s).toString(), u"Codex"_s);
        QVERIFY(decision.value(u"blocked"_s).toBool());
        QVERIFY(!decision.value(u"rule"_s).toString().isEmpty());
        QVERIFY(model.decision(u"no-such-id"_s).isEmpty());
    }

    void anUnprotectedAgentIsAProblem() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status-unprotected"_s), std::nullopt, kNow);

        QCOMPARE(column(model.problems(), u"title"_s), QStringList{u"Claude Code is not protected"_s});
        QCOMPARE(model.header().value(u"tone"_s).toString(), u"bad"_s);
        // The problem belongs to Claude Code's tab, not Codex's.
        model.setSelectedHost(u"codex"_s);
        QVERIFY(model.problems().isEmpty());
    }

    void withoutMoatItSaysHowToInstall() {
        QuickViewModel model;
        model.setData(std::nullopt, std::nullopt, kNow);
        QVERIFY(!model.available());
        QCOMPARE(model.unavailable().value(u"title"_s).toString(), u"OpenMoat isn't installed"_s);
        QVERIFY(!model.unavailable().value(u"command"_s).toString().isEmpty());
        QVERIFY(model.tabs().isEmpty());

        model.setData(std::nullopt, MoatError{MoatError::Kind::TimedOut, u"status --format json"_s, {}}, kNow);
        QCOMPARE(model.unavailable().value(u"title"_s).toString(), u"Couldn't read OpenMoat"_s);
    }

    void aFailedReadKeepsTheLastGoodData() {
        QuickViewModel model;
        model.setData(makeSnapshot(u"status"_s), MoatError{MoatError::Kind::TimedOut, u"show"_s, {}}, kNow);
        QVERIFY(model.available());
        QVERIFY(model.header().value(u"updated"_s).toString().startsWith(u"Last good data"_s));
    }

    void refreshSaysWhatHappened() {
        QuickViewModel model;
        int asked = 0;
        model.setRefreshHandler([&asked] { ++asked; });

        model.refresh();
        QCOMPARE(asked, 1);
        QCOMPARE(model.refreshState(), u"refreshing"_s);
        model.refresh(); // ignored while a read is running
        QCOMPARE(asked, 1);

        model.refreshFinished(std::nullopt);
        QCOMPARE(model.refreshState(), u"done"_s);
        QCOMPARE(model.refreshText(), u"Updated just now"_s);

        model.refresh();
        model.refreshFinished(MoatError{MoatError::Kind::TimedOut, u"status"_s, {}});
        QCOMPARE(model.refreshState(), u"failed"_s);
    }

    void readsNotAskedForLeaveRefreshAlone() {
        QuickViewModel model;
        model.refreshFinished(std::nullopt);
        QCOMPARE(model.refreshState(), u"idle"_s);
    }

    void relativeTimesMatchTheMacMenu() {
        QCOMPARE(Format::relative(kNow.addSecs(-30), kNow), u"just now"_s);
        QCOMPARE(Format::relative(kNow.addSecs(-12 * 60), kNow), u"12 min ago"_s);
        QCOMPARE(Format::relative(kNow.addSecs(-2 * 3600), kNow), Format::clock(kNow.addSecs(-2 * 3600)));
    }

    void homeIsShortenedOnlyAtAFolderBoundary() {
        QCOMPARE(Format::shortPath(u"/home/al/code"_s, u"/home/al"_s), u"~/code"_s);
        QCOMPARE(Format::shortPath(u"/home/alex/code"_s, u"/home/al"_s), u"/home/alex/code"_s);
        QCOMPARE(Format::oneLine(u"a\n  b"_s, 10), u"a b"_s);
        QCOMPARE(Format::oneLine(u"abcdefghijk"_s, 5), u"abcd…"_s);
    }
};

QTEST_MAIN(TestQuickView)
#include "tst_quickview.moc"
