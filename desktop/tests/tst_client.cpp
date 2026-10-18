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
        QStringList first;
        for (const QStringList &line : MoatClient::allowedCommands()) {
            first << line.value(0);
        }
        QCOMPARE(first, (QStringList{u"status"_s, u"show"_s, u"report"_s, u"proxy"_s, u"--version"_s, u"allowed"_s,
                                     u"secret"_s, u"doctor"_s}));
        const QList<QStringList> readers{
            {u"status"_s, u"--format"_s, u"json"_s},
            {u"show"_s, u"--since"_s, u"7d"_s, u"--format"_s, u"json"_s},
            {u"report"_s, u"--since"_s, u"today"_s, u"--format"_s, u"json"_s},
            {u"proxy"_s, u"status"_s, u"--format"_s, u"json"_s},
            {u"--version"_s},
            {u"allowed"_s, u"--format"_s, u"json"_s},
            {u"secret"_s, u"list"_s, u"--format"_s, u"json"_s},
            {u"doctor"_s, u"--format"_s, u"json"_s},
        };
        for (const QStringList &line : readers) {
            QVERIFY2(MoatClient::isAllowed(line), qPrintable(line.join(u' ')));
        }
        const QList<QStringList> writers{
            {u"allow"_s, u"--last"_s},
            {u"allow"_s, u"--remove"_s, u"approved-1"_s},
            {u"trust"_s, u"--revoke"_s, u"/repo"_s},
            {u"secret"_s, u"add"_s, u"gh"_s},
            {u"secret"_s, u"list"_s, u"--format"_s, u"json"_s, u"gh"_s},
            {u"doctor"_s},
            {u"doctor"_s, u"--accept"_s},
            {u"doctor"_s, u"--format"_s, u"json"_s, u"--accept"_s},
            {u"proxy"_s},
            {u"proxy"_s, u"install"_s},
            {u"policy"_s, u"upgrade"_s},
            {u"init"_s},
            {u"uninstall"_s},
            {u"edit"_s},
        };
        for (const QStringList &line : writers) {
            QVERIFY2(!MoatClient::isAllowed(line), qPrintable(line.join(u' ')));
        }
    }

    void detailsReadAllThreeScreens() {
        auto runner = std::make_shared<StubRunner>();
        runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.6 (OpenMoat)\n"));
        runner->stub(u"allowed"_s, fixture(u"allowed"_s));
        runner->stub(u"secret"_s, fixture(u"secret-list"_s));
        runner->stub(u"doctor"_s, fixture(u"doctor"_s));
        const Details details = MoatClient(u"moat"_s, runner).details();
        QCOMPARE(details.allowed.value->rules.size(), std::size_t{3});
        QCOMPARE(details.secrets.value->secrets.size(), std::size_t{4});
        QCOMPARE(details.checks.value->problems, 1);
        QCOMPARE(runner->calls, (QList<QStringList>{
                                    {u"--version"_s},
                                    {u"allowed"_s, u"--format"_s, u"json"_s},
                                    {u"secret"_s, u"list"_s, u"--format"_s, u"json"_s},
                                    {u"doctor"_s, u"--format"_s, u"json"_s},
                                }));
    }

    void detailsOnAnOlderMoatAreNotesNotErrors() {
        auto runner = std::make_shared<StubRunner>();
        runner->stub(u"--version"_s, QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n"));
        const Details details = MoatClient(u"moat"_s, runner).details();
        const QString note = u"This needs OpenMoat 0.5.5 or later. Update moat to see it here."_s;
        QCOMPARE(details.allowed.needsNewerMoat.value_or(QString{}), note);
        QCOMPARE(details.secrets.needsNewerMoat.value_or(QString{}), note);
        QCOMPARE(details.checks.needsNewerMoat.value_or(QString{}), note);
        QVERIFY(!details.allowed.value && !details.allowed.failed);
        QCOMPARE(runner->calls, (QList<QStringList>{{u"--version"_s}})); // commands moat lacks are not run
    }

    void screenUnknownVersionUnknownCommandGivesTheNote() {
        const auto unknown = readScreen<int>(u"0.5.5", std::nullopt, [] {
            return Result<int>{MoatError{MoatError::Kind::Failed, u"allowed"_s,
                                         u"error: unrecognized subcommand 'allowed'"_s}};
        });
        QVERIFY(unknown.needsNewerMoat.has_value());
        const auto text = readScreen<int>(u"0.5.5", std::nullopt, [] {
            return Result<int>{MoatError{MoatError::Kind::Unreadable, u"doctor"_s, {}}};
        });
        QVERIFY(text.needsNewerMoat.has_value());
        // A moat new enough that still fails is an error, and so is a timeout.
        const auto failing = readScreen<int>(u"0.5.5", u"0.5.6"_s, [] {
            return Result<int>{MoatError{MoatError::Kind::Failed, u"allowed"_s, u"error: unexpected argument"_s}};
        });
        QVERIFY(failing.failed.has_value());
        const auto timeout = readScreen<int>(u"0.5.5", std::nullopt, [] {
            return Result<int>{MoatError{MoatError::Kind::TimedOut, u"doctor --format json"_s, {}}};
        });
        QCOMPARE(timeout.failed.value_or(QString{}), u"moat doctor --format json took too long"_s);
    }

    void versionsCompareByNumber() {
        QCOMPARE(versionAtLeast(u"0.5.5"_s, u"0.5.5"), std::optional<bool>{true});
        QCOMPARE(versionAtLeast(u"0.5.10"_s, u"0.5.7"), std::optional<bool>{true});
        QCOMPARE(versionAtLeast(u"0.5.4"_s, u"0.5.5"), std::optional<bool>{false});
        QCOMPARE(versionAtLeast(u"0.5.7-rc.1"_s, u"0.5.7"), std::optional<bool>{true});
        QVERIFY(!versionAtLeast(std::nullopt, u"0.5.5").has_value());
        QVERIFY(!versionAtLeast(u"dev"_s, u"0.5.5").has_value());
    }

#ifndef Q_OS_WIN
    void processRunnerAcceptsListedExitCodesOnlyWithOutput() {
        ProcessRunner runner;
        const QStringList printed{u"-c"_s, u"printf '{}'; exit 64"_s};
        const auto out = runner.runAccepting(u"/bin/sh"_s, printed, std::chrono::seconds{5}, {0, 64});
        QVERIFY(out.ok());
        QCOMPARE(out.value(), QByteArrayLiteral("{}"));
        QVERIFY(!runner.run(u"/bin/sh"_s, printed, std::chrono::seconds{5}).ok());
        const QStringList silent{u"-c"_s, u"echo 'moat: no policy' >&2; exit 64"_s};
        const auto failed = runner.runAccepting(u"/bin/sh"_s, silent, std::chrono::seconds{5}, {0, 64});
        QVERIFY(!failed.ok());
        QCOMPARE(failed.error().detail, u"no policy"_s);
    }
#endif

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
