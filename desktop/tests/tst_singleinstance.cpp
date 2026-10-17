#include "app/SingleInstance.hpp"

#include <QSignalSpy>
#include <QTest>
#include <QUuid>

#include <chrono>
#include <future>
#include <utility>

using namespace Qt::StringLiterals;
using namespace moatbar;

namespace {

/// A socket name of the test's own, never the real MoatBar's.
QString scratchName() {
    return u"moatbar-test-"_s + QUuid::createUuid().toString(QUuid::Id128).left(12);
}

/// Run `work` on another thread while this thread keeps its event loop going
/// (on Windows a pipe write waits for the other end to read).
template <typename Work>
auto fromAnotherThread(Work work) {
    auto result = std::async(std::launch::async, std::move(work));
    // result.get() below waits for the rest, if any.
    static_cast<void>(QTest::qWaitFor(
        [&result] { return result.wait_for(std::chrono::seconds{0}) == std::future_status::ready; }, 10000));
    return result.get();
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

        // The later start runs on its own thread, as it would in its own
        // process, while this thread's event loop serves the running one.
        const auto [listened, sent] = fromAnotherThread([name] {
            SingleInstance later(name);
            const bool listenedToo = later.listen();
            return std::pair{listenedToo, later.sendToRunning(u"activity"_s)};
        });
        QVERIFY(!listened);
        QVERIFY(sent);
        QVERIFY(requests.count() == 1 || requests.wait(3000));
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
        QVERIFY(fromAnotherThread([name] { return SingleInstance(name).sendToRunning(u"ping"_s); }));
        QVERIFY(!requests.wait(500));
    }

    void theSocketNameIsPerUser() {
        QVERIFY(SingleInstance::defaultName().startsWith(u"dev.openmoat.moatbar-"_s));
        QVERIFY(!SingleInstance::defaultName().contains(u'/'));
    }
};

QTEST_MAIN(TestSingleInstance)
#include "tst_singleinstance.moc"
