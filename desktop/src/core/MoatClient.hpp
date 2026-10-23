#pragma once

#include "core/Details.hpp"
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

    /// The same, but an exit code in `okExitCodes` that printed something is
    /// not a failure (`openmoat doctor` after a failed check). Runners with canned
    /// output (tests) need not override it.
    [[nodiscard]] virtual Result<QByteArray> runAccepting(const QString &program, const QStringList &arguments,
                                                          std::chrono::milliseconds timeout,
                                                          const QList<int> & /*okExitCodes*/) {
        return run(program, arguments, timeout);
    }
};

/// Runs a real process with a deadline. Safe to call from a worker thread.
class ProcessRunner final : public CommandRunner {
public:
    [[nodiscard]] Result<QByteArray> run(const QString &program, const QStringList &arguments,
                                         std::chrono::milliseconds timeout) override;
    [[nodiscard]] Result<QByteArray> runAccepting(const QString &program, const QStringList &arguments,
                                                  std::chrono::milliseconds timeout,
                                                  const QList<int> &okExitCodes) override;
};

/// Reads moat. Runs only the read-only commands in `allowedCommands()` and
/// decodes their JSON; OpenMoat Bar never runs a moat command that changes anything.
class MoatClient {
public:
    using IsExecutable = std::function<bool(const QString &path)>;

    /// The only moat command lines OpenMoat Bar ever runs, word for word; `*` is one
    /// `--since` value. Whole lines, not just the first word: `doctor` re-pins
    /// with `--accept`, `secret add` edits the policy, `proxy` alone runs the proxy.
    [[nodiscard]] static const QList<QStringList> &allowedCommands();
    /// Whether `arguments` is one of `allowedCommands()`.
    [[nodiscard]] static bool isAllowed(const QStringList &arguments);

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
    /// What the person allowed (OpenMoat 0.5.5 and later).
    [[nodiscard]] Result<AllowedReport> allowed() const;
    /// Brokered secrets, never their values (OpenMoat 0.5.5 and later).
    [[nodiscard]] Result<SecretList> secrets() const;
    /// Every `openmoat doctor` check (OpenMoat 0.5.5 and later).
    [[nodiscard]] Result<DoctorReport> doctor() const;

    /// The three detail screens. A moat older than 0.5.5 gets a note per
    /// screen instead of an error, without running the commands it lacks.
    [[nodiscard]] Details details(const QDateTime &now = QDateTime::currentDateTime()) const;

    /// Everything the tray needs. Status and events are required; the proxy
    /// state (absent on Windows) and version are shown when moat gives them.
    [[nodiscard]] Result<Snapshot> snapshot(const QDateTime &now = QDateTime::currentDateTime()) const;

    [[nodiscard]] const QString &binary() const noexcept { return m_binary; }

private:
    [[nodiscard]] Result<QByteArray> run(const QStringList &arguments, const QList<int> &okExitCodes = {0}) const;

    QString m_binary;
    std::shared_ptr<CommandRunner> m_runner;
    std::chrono::milliseconds m_timeout;
};

} // namespace moatbar
