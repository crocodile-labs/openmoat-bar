#include "Fixtures.hpp"
#include "app/Preferences.hpp"
#include "core/Json.hpp"
#include "core/RuleThrottle.hpp"
#include "core/Snapshot.hpp"

#include <QFile>
#include <QSettings>
#include <QTemporaryDir>
#include <QTimeZone>

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

namespace {

Snapshot snapshotWith(qsizetype eventCount) {
    auto events = json::parseEvents(fixture(u"show-today"_s)).value();
    events.resize(static_cast<std::size_t>(eventCount));
    return Snapshot{json::parseStatus(fixture(u"status"_s)).value(), std::move(events), std::nullopt, std::nullopt,
                    QDateTime::fromMSecsSinceEpoch(1792061000000)};
}

QStringList ids(const std::vector<Event> &list) {
    QStringList out;
    for (const Event &event : list) {
        out << event.id;
    }
    return out;
}

/// Preferences that live in `dir` only: never the person's real settings.
std::unique_ptr<Preferences> scratchPreferences(const QTemporaryDir &dir) {
    return std::make_unique<Preferences>(
        std::make_unique<QSettings>(dir.filePath(u"moatbar.ini"_s), QSettings::IniFormat),
        dir.filePath(u"autostart"_s), u"/opt/Moat Bar/moatbar"_s);
}

} // namespace

class TestSettings : public QObject {
    Q_OBJECT

private slots:
    // The same cases as the macOS app's ChangesTests and RuleThrottleTests.
    void newBlocksOnlyAfterTheFirstRead() {
        const Snapshot early = snapshotWith(2);
        const Snapshot later = snapshotWith(8);
        QVERIFY(newBlocks(nullptr, later).empty());
        QCOMPARE(ids(newBlocks(&early, later)), (QStringList{u"1c"_s, u"1e"_s}));
        QVERIFY(newBlocks(&later, later).empty());
    }

    void throttleAllowsOncePerRulePerPeriod() {
        RuleThrottle throttle(std::chrono::seconds{600});
        const QDateTime start = QDateTime::fromSecsSinceEpoch(0, QTimeZone::utc());
        QVERIFY(throttle.allow(u"secrets-paths"_s, start));
        QVERIFY(!throttle.allow(u"secrets-paths"_s, start.addSecs(599)));
        QVERIFY(throttle.allow(u"destructive"_s, start.addSecs(1))); // rules are counted apart
        QVERIFY(throttle.allow(u"secrets-paths"_s, start.addSecs(600)));
    }

    void blockNotificationsAreOffUntilTurnedOn() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        auto preferences = scratchPreferences(dir);
        QVERIFY(!preferences->notifyBlocks());
        QVERIFY(!preferences->welcomed());

        preferences->setNotifyBlocks(true);
        preferences->setWelcomed(true);
        preferences.reset(); // saved, and read back by a new instance
        preferences = scratchPreferences(dir);
        QVERIFY(preferences->notifyBlocks());
        QVERIFY(preferences->welcomed());
    }

    void startAtLoginWritesAndRemovesTheAutostartEntry() {
#ifdef Q_OS_WIN
        QSKIP("On Windows this is the per-user Run key; the test does not touch the real registry.");
#else
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        auto preferences = scratchPreferences(dir);
        QVERIFY(Preferences::canStartAtLogin());
        QVERIFY(!preferences->startAtLogin());

        preferences->setStartAtLogin(true);
        QVERIFY(preferences->startAtLogin());
        QCOMPARE(preferences->startAtLoginError(), QString{});
        QFile entry(preferences->autostartFile());
        QVERIFY(entry.open(QIODevice::ReadOnly));
        const QString text = QString::fromUtf8(entry.readAll());
        QVERIFY(text.startsWith(u"[Desktop Entry]\n"_s));
        // The path is quoted, so a space in it keeps it one argument.
        QVERIFY(text.contains(u"\nExec=\"/opt/Moat Bar/moatbar\"\n"_s));
        entry.close();

        preferences->setStartAtLogin(false);
        QVERIFY(!preferences->startAtLogin());
        QVERIFY(!QFile::exists(preferences->autostartFile()));
#endif
    }
};

QTEST_MAIN(TestSettings)
#include "tst_settings.moc"
