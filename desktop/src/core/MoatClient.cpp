#include "core/MoatClient.hpp"
#include "core/Json.hpp"

#include <QDir>
#include <QFileInfo>
#include <QProcess>
#include <utility>

using namespace Qt::StringLiterals;

namespace moatbar {

// MARK: - ProcessRunner

Result<QByteArray> ProcessRunner::run(const QString &program, const QStringList &arguments,
                                      std::chrono::milliseconds timeout) {
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
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
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

const QStringList &MoatClient::allowedCommands() {
    static const QStringList commands{u"status"_s, u"show"_s, u"report"_s, u"proxy"_s, u"--version"_s};
    return commands;
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
    const QString name = u"moat.exe"_s;
    const QString home = environment.value(u"USERPROFILE"_s, QDir::homePath());
#else
    const QString name = u"moat"_s;
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
    for (const QString &dir : std::as_const(dirs)) {
        const QString candidate = QDir(dir).filePath(name);
        if (executable(candidate)) {
            return QDir::toNativeSeparators(candidate);
        }
    }
    return std::nullopt;
}

MoatClient::MoatClient(QString binary, std::shared_ptr<CommandRunner> runner, std::chrono::milliseconds timeout)
    : m_binary(std::move(binary)), m_runner(std::move(runner)), m_timeout(timeout) {}

Result<QByteArray> MoatClient::run(const QStringList &arguments) const {
    // A programming error, not a runtime one: MoatBar must never run anything else.
    Q_ASSERT(!arguments.isEmpty() && allowedCommands().contains(arguments.first()));
    if (arguments.isEmpty() || !allowedCommands().contains(arguments.first())) {
        return MoatError{MoatError::Kind::Failed, arguments.value(0), u"not a read-only command"_s};
    }
    return m_runner->run(m_binary, arguments, m_timeout);
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
