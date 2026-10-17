#pragma once

#include <QObject>
#include <QSettings>

#include <memory>

namespace moatbar {

/// MoatBar's own settings, the only things it ever saves. Nothing here
/// touches OpenMoat or ~/.moat.
///   - block notifications: off by default (MoatBar is quiet)
///   - the welcome window was shown
///   - start at login: an XDG autostart entry on Linux, the per-user Run key
///     on Windows; off until the person turns it on
class Preferences final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool notifyBlocks READ notifyBlocks WRITE setNotifyBlocks NOTIFY changed)
    Q_PROPERTY(bool startAtLogin READ startAtLogin WRITE setStartAtLogin NOTIFY changed)
    Q_PROPERTY(bool canStartAtLogin READ canStartAtLogin CONSTANT)
    Q_PROPERTY(QString startAtLoginError READ startAtLoginError NOTIFY changed)
    Q_PROPERTY(QString moatPath READ moatPath NOTIFY changed)
    Q_PROPERTY(QString moatVersion READ moatVersion NOTIFY changed)

public:
    /// The app's settings and the desktop's own autostart folder.
    explicit Preferences(QObject *parent = nullptr);
    /// Explicit places, for tests: never the person's real settings.
    Preferences(std::unique_ptr<QSettings> settings, QString autostartDir, QString executable,
                QObject *parent = nullptr);
    ~Preferences() override;

    [[nodiscard]] bool notifyBlocks() const;
    void setNotifyBlocks(bool on);

    [[nodiscard]] bool welcomed() const;
    void setWelcomed(bool shown);

    [[nodiscard]] static bool canStartAtLogin();
    [[nodiscard]] bool startAtLogin() const;
    void setStartAtLogin(bool on);
    [[nodiscard]] QString startAtLoginError() const { return m_startAtLoginError; }

    [[nodiscard]] QString moatPath() const { return m_moatPath; }
    [[nodiscard]] QString moatVersion() const { return m_moatVersion; }
    void setMoat(const QString &path, const QString &version);

    /// The autostart entry's path (Linux).
    [[nodiscard]] QString autostartFile() const;

signals:
    void changed();

private:
    std::unique_ptr<QSettings> m_settings;
    QString m_autostartDir;
    QString m_executable;
    QString m_startAtLoginError;
    QString m_moatPath;
    QString m_moatVersion;
};

} // namespace moatbar
