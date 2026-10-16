#include "Fixtures.hpp"

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::StubRunner;
using moatbar::test::fixture;

class TestClient : public QObject {
    Q_OBJECT

private slots:
    void snapshotReadsStatusEventsProxyAndVersion() {
        auto runner = std::make_shared<StubRunner>();
        runner->stub(u"status"_s, fixture(u"status"_s));
        runner->stub(u"show"_s, fixture(u"show-today"_s));
        runner->stub(u"proxy"_s, fixture(u"proxy-running"_s));
        runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n"));
        const MoatClient client(u"/usr/local/bin/moat"_s, runner);

        const auto snapshot = client.snapshot();

        QVERIFY(snapshot.ok());
        QCOMPARE(snapshot.value().status.agents.size(), std::size_t{3});
        QCOMPARE(snapshot.value().events.size(), std::size_t{8});
        QVERIFY(snapshot.value().proxy && snapshot.value().proxy->running());
        QCOMPARE(snapshot.value().moatVersion.value_or(QString{}), u"0.5.3"_s);
        QCOMPARE(runner->calls,
                 (QList<QStringList>{
                     {u"status"_s, u"--format"_s, u"json"_s},
                     {u"show"_s, u"--since"_s, u"today"_s, u"--format"_s, u"json"_s},
                     {u"proxy"_s, u"status"_s, u"--format"_s, u"json"_s},
                     {u"--version"_s},
                 }));
    }

    void snapshotWithoutProxyOrVersionStillWorks() {
        auto runner = std::make_shared<StubRunner>();
        runner->stub(u"status"_s, fixture(u"status"_s));
        runner->stub(u"show"_s, fixture(u"show-today"_s));
        const auto snapshot = MoatClient(u"moat"_s, runner).snapshot();
        QVERIFY(snapshot.ok());
        QVERIFY(!snapshot.value().proxy.has_value());
        QVERIFY(!snapshot.value().moatVersion.has_value());
    }

    void statusFailureFailsTheSnapshot() {
        auto runner = std::make_shared<StubRunner>();
        const MoatError timeout{MoatError::Kind::TimedOut, u"status --format json"_s, {}};
        runner->stub(u"status"_s, timeout);
        const auto snapshot = MoatClient(u"moat"_s, runner).snapshot();
        QVERIFY(!snapshot.ok());
        QVERIFY(snapshot.error() == timeout);
    }

    void eventsSincePassesTheWindow() {
        auto runner = std::make_shared<StubRunner>();
        runner->stub(u"show"_s, fixture(u"show-today"_s));
        QVERIFY(MoatClient(u"moat"_s, runner).events(TimeWindow::SevenDays).ok());
        QCOMPARE(runner->calls.front(), (QStringList{u"show"_s, u"--since"_s, u"7d"_s, u"--format"_s, u"json"_s}));
    }

    void onlyReadOnlyCommandsAreAllowed() {
        const QStringList &allowed = MoatClient::allowedCommands();
        QCOMPARE(allowed, (QStringList{u"status"_s, u"show"_s, u"report"_s, u"proxy"_s, u"--version"_s}));
        for (const QString &writer : {u"allow"_s, u"edit"_s, u"trust"_s, u"secret"_s, u"init"_s, u"uninstall"_s,
                                      u"doctor"_s, u"policy"_s}) {
            QVERIFY2(!allowed.contains(writer), qPrintable(writer));
        }
    }

    void locatePrefersPathThenInstallerPlaces() {
        QProcessEnvironment env;
#ifdef Q_OS_WIN
        env.insert(u"PATH"_s, u"C:/Windows;C:/custom/bin"_s);
        env.insert(u"USERPROFILE"_s, u"C:/Users/you"_s);
        const QString onPath = u"C:/custom/bin/moat.exe"_s;
        const QString cargo = u"C:/Users/you/.cargo/bin/moat.exe"_s;
#else
        env.insert(u"PATH"_s, u"/usr/bin:/custom/bin"_s);
        env.insert(u"HOME"_s, u"/home/you"_s);
        const QString onPath = u"/custom/bin/moat"_s;
        const QString cargo = u"/home/you/.cargo/bin/moat"_s;
#endif
        const auto only = [](const QString &wanted) {
            return [wanted](const QString &path) { return QDir::fromNativeSeparators(path) == wanted; };
        };
        QCOMPARE(QDir::fromNativeSeparators(MoatClient::locate(env, only(onPath)).value_or(QString{})), onPath);
        QCOMPARE(QDir::fromNativeSeparators(MoatClient::locate(env, only(cargo)).value_or(QString{})), cargo);
        QVERIFY(!MoatClient::locate(env, [](const QString &) { return false; }).has_value());
    }
};

QTEST_GUILESS_MAIN(TestClient)
#include "tst_client.moc"
