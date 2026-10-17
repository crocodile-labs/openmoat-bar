#include "Fixtures.hpp"
#include "app/ActivityModel.hpp"
#include "core/ActivityFilter.hpp"
#include "core/Json.hpp"

#include <QJsonDocument>

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

namespace {

std::vector<Event> events() {
    return json::parseEvents(fixture(u"show-today"_s)).value();
}

StatusReport status() {
    return json::parseStatus(fixture(u"status"_s)).value();
}

QStringList ids(const std::vector<Event> &list) {
    QStringList out;
    for (const Event &event : list) {
        out << event.id;
    }
    return out;
}

QStringList column(const QVariantList &rows, const QString &key) {
    QStringList out;
    for (const QVariant &row : rows) {
        out << row.toMap().value(key).toString();
    }
    return out;
}

} // namespace

class TestActivity : public QObject {
    Q_OBJECT

private slots:
    // The same cases as the macOS app's ActivityFilterTests.
    void filterDefaultsToBlockedNewestFirst() {
        QCOMPARE(ids(ActivityFilter{}.apply(events())), (QStringList{u"1e"_s, u"1c"_s, u"1b"_s}));
    }

    void filterByAgentVerdictAndRule() {
        const auto all = events();
        // (Filters are built outside QCOMPARE: commas in braces split macro arguments.)
        const ActivityFilter codex{u"codex"_s, std::nullopt, {}};
        const ActivityFilter secrets{{}, Verdict::Deny, u"secrets-paths"_s};
        const ActivityFilter everything{{}, std::nullopt, {}};
        QCOMPARE(ids(codex.apply(all)), (QStringList{u"1e"_s, u"1d"_s}));
        QCOMPARE(ids(secrets.apply(all)), (QStringList{u"1e"_s, u"1c"_s}));
        QCOMPARE(everything.apply(all).size(), std::size_t{8});
    }

    void exportIsMoatsOwnJsonOneLineEach() {
        const auto all = events();
        const QByteArray lines = json::toJsonLines(all);
        const QList<QByteArray> split = lines.trimmed().split('\n');
        QCOMPARE(split.size(), qsizetype{8});
        for (qsizetype i = 0; i < split.size(); ++i) {
            const QJsonDocument line = QJsonDocument::fromJson(split[i]);
            QVERIFY(line.isObject());
            QCOMPARE(line.object(), all[static_cast<std::size_t>(i)].raw);
        }
        // Read back, it is the same events.
        const QByteArray asArray = "[" + split.join(',') + "]";
        QCOMPARE(ids(json::parseEvents(asArray).value()), ids(all));
    }

    void modelShowsTheFilteredRowsAndSelectsTheNewest() {
        ActivityModel model;
        model.setData(status(), events());

        QCOMPARE(model.verdict(), u"deny"_s);
        QCOMPARE(column(model.rows(), u"id"_s), (QStringList{u"1e"_s, u"1c"_s, u"1b"_s}));
        QCOMPARE(model.selectedId(), u"1e"_s);
        QCOMPARE(model.selected().value(u"agent"_s).toString(), u"Codex"_s);
        QCOMPARE(model.rowsNote(), u"3 calls"_s);
        QCOMPARE(column(model.verdictCounts(), u"countText"_s),
                 (QStringList{u"3"_s, u"1"_s, u"1"_s, u"3"_s, u"8"_s}));
        QCOMPARE(column(model.agents(), u"host"_s), (QStringList{u"claude-code"_s, u"codex"_s}));
        QVERIFY(!model.topRules().isEmpty());
    }

    void changingTheFilterKeepsASelectionThatIsStillShown() {
        ActivityModel model;
        model.setData(status(), events());
        model.setSelectedId(u"1c"_s);

        model.setRule(u"secrets-paths"_s);
        QCOMPARE(column(model.rows(), u"id"_s), (QStringList{u"1e"_s, u"1c"_s}));
        QCOMPARE(model.selectedId(), u"1c"_s);

        model.setHost(u"codex"_s);
        QCOMPARE(column(model.rows(), u"id"_s), QStringList{u"1e"_s});
        QCOMPARE(model.selectedId(), u"1e"_s);

        model.toggleRule(u"secrets-paths"_s);
        QCOMPARE(model.rule(), QString{});
    }

    void aNewVerdictStartsAtItsNewestCall() {
        ActivityModel model;
        model.setData(status(), events());
        model.setVerdict(QString{});
        QCOMPARE(model.verdict(), QString{});
        QCOMPARE(model.rows().size(), qsizetype{8});
        QCOMPARE(model.selectedId(), u"21"_s);

        model.setVerdict(u"ask"_s);
        QCOMPARE(column(model.rows(), u"id"_s), QStringList{u"1f"_s});
        QCOMPARE(model.selectedId(), u"1f"_s);
    }

    void nothingMatchingSelectsNothing() {
        ActivityModel model;
        model.setData(status(), events());
        model.setHost(u"cursor"_s);
        QVERIFY(model.rows().isEmpty());
        QCOMPARE(model.selectedId(), QString{});
        QVERIFY(model.selected().isEmpty());
        QCOMPARE(model.rowsNote(), u"0 calls"_s);
    }
};

QTEST_MAIN(TestActivity)
#include "tst_activity.moc"
