#pragma once

#include "core/Models.hpp"
#include "core/Result.hpp"
#include "core/Snapshot.hpp"

#include <QByteArray>
#include <QProcessEnvironment>
#include <QStringList>

#include <chrono>
#include <functional>
#include <memory>

namespace moatbar {

/// Runs a program and returns what it printed. The seam tests replace: the app
/// uses `ProcessRunner`, tests use a stub that returns fixtures.
class CommandRunner {
public:
    CommandRunner() = default;
    CommandRunner(const CommandRunner &) = delete;
    CommandRunner &operator=(const CommandRunner &) = delete;
    CommandRunner(CommandRunner &&) = delete;
    CommandRunner &operator=(CommandRunner &&) = delete;
    virtual ~CommandRunner() = default;

    [[nodiscard]] virtual Result<QByteArray> run(const QString &program, const QStringList &arguments,
                                                 std::chrono::milliseconds timeout) = 0;
};

/// Runs a real process with a deadline. Safe to call from a worker thread.
class ProcessRunner final : public CommandRunner {
public:
    [[nodiscard]] Result<QByteArray> run(const QString &program, const QStringList &arguments,
                                         std::chrono::milliseconds timeout) override;
};

/// Reads moat. Runs only the read-only commands in `allowedCommands()` and
/// decodes their JSON; MoatBar never runs a moat command that changes anything.
class MoatClient {
public:
    using IsExecutable = std::function<bool(const QString &path)>;

    /// The only moat subcommands MoatBar ever runs.
    [[nodiscard]] static const QStringList &allowedCommands();

    /// Find moat on `PATH`, then where the installers put it (Homebrew,
    /// `~/.cargo/bin`, the Windows installer's `%USERPROFILE%\.cargo\bin`).
    [[nodiscard]] static std::optional<QString> locate(
        const QProcessEnvironment &environment = QProcessEnvironment::systemEnvironment(),
        const IsExecutable &isExecutable = {});

    explicit MoatClient(QString binary, std::shared_ptr<CommandRunner> runner = std::make_shared<ProcessRunner>(),
                        std::chrono::milliseconds timeout = std::chrono::seconds{3});

    [[nodiscard]] Result<StatusReport> status() const;
    [[nodiscard]] Result<std::vector<Event>> events(TimeWindow window) const;
    [[nodiscard]] Result<Summary> report(TimeWindow window) const;
    [[nodiscard]] Result<ProxyState> proxyStatus() const;
    [[nodiscard]] Result<QString> version() const;

    /// Everything the tray needs. Status and events are required; the proxy
    /// state (absent on Windows) and version are shown when moat gives them.
    [[nodiscard]] Result<Snapshot> snapshot(const QDateTime &now = QDateTime::currentDateTime()) const;

    [[nodiscard]] const QString &binary() const noexcept { return m_binary; }

private:
    [[nodiscard]] Result<QByteArray> run(const QStringList &arguments) const;

    QString m_binary;
    std::shared_ptr<CommandRunner> m_runner;
    std::chrono::milliseconds m_timeout;
};

} // namespace moatbar
