#include "core/MoatClient.hpp"
#include "core/Json.hpp"

#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <algorithm>
#include <utility>

using namespace Qt::StringLiterals;

namespace moatbar {

// MARK: - ProcessRunner

Result<QByteArray> ProcessRunner::run(const QString &program, const QStringList &arguments,
                                      std::chrono::milliseconds timeout) {
    return runAccepting(program, arguments, timeout, {0});
}

Result<QByteArray> ProcessRunner::runAccepting(const QString &program, const QStringList &arguments,
                                               std::chrono::milliseconds timeout, const QList<int> &okExitCodes) {
    const QString command = arguments.isEmpty() ? QString{} : arguments.first();
    QProcess process;
    process.setProgram(program);
    process.setArguments(arguments);
    process.setStandardInputFile(QProcess::nullDevice());
    process.start(QIODevice::ReadOnly);
    if (!process.waitForStarted(static_cast<int>(timeout.count()))) {
        return MoatError{MoatError::Kind::NotInstalled, command, process.errorString()};
    }
    // QProcess buffers both pipes while it waits, so a large output can't stall moat.
    if (!process.waitForFinished(static_cast<int>(timeout.count()))) {
        process.kill();
        process.waitForFinished(1000);
        return MoatError{MoatError::Kind::TimedOut, arguments.join(u' '), {}};
    }
    const QByteArray out = process.readAllStandardOutput();
    const int code = process.exitCode();
    const bool accepted = code == 0 || (okExitCodes.contains(code) && !out.isEmpty());
    if (process.exitStatus() != QProcess::NormalExit || !accepted) {
        const QByteArray err = process.readAllStandardError();
        QString first = QString::fromUtf8(err.isEmpty() ? out : err).section(u'\n', 0, 0).trimmed();
        if (first.startsWith(u"moat: ")) {
            first = first.mid(6);
        }
        if (first.isEmpty()) {
            first = u"exit %1"_s.arg(process.exitCode());
        }
        return MoatError{MoatError::Kind::Failed, command, first};
    }
    return out;
}

// MARK: - MoatClient

const QList<QStringList> &MoatClient::allowedCommands() {
    static const QList<QStringList> commands{
        {u"status"_s, u"--format"_s, u"json"_s},
        {u"show"_s, u"--since"_s, u"*"_s, u"--format"_s, u"json"_s},
        {u"report"_s, u"--since"_s, u"*"_s, u"--format"_s, u"json"_s},
        {u"proxy"_s, u"status"_s, u"--format"_s, u"json"_s},
        {u"--version"_s},
        {u"allowed"_s, u"--format"_s, u"json"_s},
        {u"secret"_s, u"list"_s, u"--format"_s, u"json"_s},
        {u"doctor"_s, u"--format"_s, u"json"_s},
    };
    return commands;
}

bool MoatClient::isAllowed(const QStringList &arguments) {
    return std::ranges::any_of(allowedCommands(), [&arguments](const QStringList &line) {
        if (line.size() != arguments.size()) {
            return false;
        }
        for (qsizetype i = 0; i < line.size(); ++i) {
            if (line[i] != u"*" && line[i] != arguments[i]) {
                return false;
            }
        }
        return true;
    });
}

std::optional<QString> MoatClient::locate(const QProcessEnvironment &environment, const IsExecutable &isExecutable) {
    IsExecutable executable = isExecutable;
    if (!executable) {
        executable = [](const QString &path) {
            const QFileInfo info(path);
            return info.isFile() && info.isExecutable();
        };
    }
#ifdef Q_OS_WIN
    const QStringList names{u"openmoat.exe"_s, u"moat.exe"_s};
    const QString home = environment.value(u"USERPROFILE"_s, QDir::homePath());
#else
    const QStringList names{u"openmoat"_s, u"moat"_s};
    const QString home = environment.value(u"HOME"_s, QDir::homePath());
#endif
    // A tray app started by the desktop session can get a short PATH, so the
    // installers' locations are listed after it.
    QStringList dirs = environment.value(u"PATH"_s).split(QDir::listSeparator(), Qt::SkipEmptyParts);
    dirs << QDir(home).filePath(u".cargo/bin"_s);
#ifndef Q_OS_WIN
    dirs << u"/home/linuxbrew/.linuxbrew/bin"_s << QDir(home).filePath(u".local/bin"_s) << u"/usr/local/bin"_s
         << u"/opt/homebrew/bin"_s;
#endif
    // An install from before the rename has only `moat`: looked for everywhere
    // after `openmoat`, since the old name goes away in a later release.
    for (const QString &name : names) {
        for (const QString &dir : std::as_const(dirs)) {
            const QString candidate = QDir(dir).filePath(name);
            if (executable(candidate)) {
                return QDir::toNativeSeparators(candidate);
            }
        }
    }
    return std::nullopt;
}

MoatClient::MoatClient(QString binary, std::shared_ptr<CommandRunner> runner, std::chrono::milliseconds timeout)
    : m_binary(std::move(binary)), m_runner(std::move(runner)), m_timeout(timeout) {}

Result<QByteArray> MoatClient::run(const QStringList &arguments, const QList<int> &okExitCodes) const {
    // A programming error, not a runtime one: MoatBar must never run anything else.
    Q_ASSERT(isAllowed(arguments));
    if (!isAllowed(arguments)) {
        return MoatError{MoatError::Kind::Failed, arguments.value(0), u"not a read-only command"_s};
    }
    if (okExitCodes == QList<int>{0}) {
        return m_runner->run(m_binary, arguments, m_timeout);
    }
    return m_runner->runAccepting(m_binary, arguments, m_timeout, okExitCodes);
}

Result<StatusReport> MoatClient::status() const {
    const auto bytes = run({u"status"_s, u"--format"_s, u"json"_s});
    return bytes ? json::parseStatus(bytes.value()) : Result<StatusReport>{bytes.error()};
}

Result<std::vector<Event>> MoatClient::events(TimeWindow window) const {
    const auto bytes = run({u"show"_s, u"--since"_s, timeWindowWire(window), u"--format"_s, u"json"_s});
    return bytes ? json::parseEvents(bytes.value()) : Result<std::vector<Event>>{bytes.error()};
}

Result<Summary> MoatClient::report(TimeWindow window) const {
    const auto bytes = run({u"report"_s, u"--since"_s, timeWindowWire(window), u"--format"_s, u"json"_s});
    return bytes ? json::parseSummary(bytes.value()) : Result<Summary>{bytes.error()};
}

Result<ProxyState> MoatClient::proxyStatus() const {
    const auto bytes = run({u"proxy"_s, u"status"_s, u"--format"_s, u"json"_s});
    return bytes ? json::parseProxy(bytes.value()) : Result<ProxyState>{bytes.error()};
}

Result<QString> MoatClient::version() const {
    const auto bytes = run({u"--version"_s});
    return bytes ? json::parseVersion(bytes.value()) : Result<QString>{bytes.error()};
}

Result<AllowedReport> MoatClient::allowed() const {
    const auto bytes = run({u"allowed"_s, u"--format"_s, u"json"_s});
    return bytes ? json::parseAllowed(bytes.value()) : Result<AllowedReport>{bytes.error()};
}

Result<SecretList> MoatClient::secrets() const {
    const auto bytes = run({u"secret"_s, u"list"_s, u"--format"_s, u"json"_s});
    return bytes ? json::parseSecrets(bytes.value()) : Result<SecretList>{bytes.error()};
}

Result<DoctorReport> MoatClient::doctor() const {
    // moat exits 64 after printing the checks when one of them is a problem.
    const auto bytes = run({u"doctor"_s, u"--format"_s, u"json"_s}, {0, 64});
    return bytes ? json::parseDoctor(bytes.value()) : Result<DoctorReport>{bytes.error()};
}

Details MoatClient::details(const QDateTime &now) const {
    const auto ver = version();
    const std::optional<QString> known = ver ? std::optional<QString>{ver.value()} : std::nullopt;
    const QString minimum = MoatRequirement::screens();
    return Details{
        readScreen<AllowedReport>(minimum, known, [this] { return allowed(); }),
        readScreen<SecretList>(minimum, known, [this] { return secrets(); }),
        readScreen<DoctorReport>(minimum, known, [this] { return doctor(); }),
        now,
    };
}

Result<Snapshot> MoatClient::snapshot(const QDateTime &now) const {
    auto status = this->status();
    if (!status) {
        return status.error();
    }
    auto events = this->events(TimeWindow::Today);
    if (!events) {
        return events.error();
    }
    const auto proxy = proxyStatus();
    const auto ver = version();
    return Snapshot{
        std::move(status).value(),
        std::move(events).value(),
        proxy ? std::optional<ProxyState>{proxy.value()} : std::nullopt,
        ver ? std::optional<QString>{ver.value()} : std::nullopt,
        now,
    };
}

} // namespace moatbar
