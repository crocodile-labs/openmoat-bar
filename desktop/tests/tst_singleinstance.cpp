#include "app/SingleInstance.hpp"

#include <QSignalSpy>
#include <QTest>
#include <QUuid>

using namespace Qt::StringLiterals;
using namespace moatbar;

namespace {

/// A socket name of the test's own, never the real MoatBar's.
QString scratchName() {
    return u"moatbar-test-"_s + QUuid::createUuid().toString(QUuid::Id128).left(12);
}

} // namespace

class TestSingleInstance : public QObject {
    Q_OBJECT

private slots:
    void aLaterStartHandsItsRequestToTheRunningOne() {
        const QString name = scratchName();
        SingleInstance running(name);
        QVERIFY(running.listen());
        QSignalSpy requests(&running, &SingleInstance::requested);

        SingleInstance later(name);
        QVERIFY(!later.listen());
        QVERIFY(later.sendToRunning(u"activity"_s));
        QVERIFY(requests.wait(3000));
        QCOMPARE(requests.first().first().toString(), u"activity"_s);
    }

    void nothingRunningMeansNobodyTakesTheRequest() {
        const SingleInstance alone(scratchName());
        QVERIFY(!alone.sendToRunning(u"show"_s, 300));
    }

    void onlyKnownRequestsAreActedOn() {
        QVERIFY(SingleInstance::isRequest(u"show"_s));
        QVERIFY(SingleInstance::isRequest(u"quit"_s));
        QVERIFY(!SingleInstance::isRequest(u"ping"_s));
        QVERIFY(!SingleInstance::isRequest(u"rm -rf ~"_s));

        const QString name = scratchName();
        SingleInstance running(name);
        QVERIFY(running.listen());
        QSignalSpy requests(&running, &SingleInstance::requested);
        QVERIFY(SingleInstance(name).sendToRunning(u"ping"_s));
        QVERIFY(!requests.wait(500));
    }

    void theSocketNameIsPerUser() {
        QVERIFY(SingleInstance::defaultName().startsWith(u"dev.openmoat.moatbar-"_s));
        QVERIFY(!SingleInstance::defaultName().contains(u'/'));
    }
};

QTEST_MAIN(TestSingleInstance)
#include "tst_singleinstance.moc"
