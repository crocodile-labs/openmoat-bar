#include "app/Preferences.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QSaveFile>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

const QString kNotifyBlocks = u"notifyBlocks"_s;
const QString kWelcomed = u"welcomed"_s;
const QString kEntryName = u"dev.openmoat.moatbar.desktop"_s;

#ifdef Q_OS_WIN
const QString kRunKey = u"HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"_s;
const QString kRunValue = u"MoatBar"_s;
#else
/// A desktop-entry Exec value: the path in double quotes, with `"`, `` ` ``,
/// `$` and `\` escaped as the spec asks.
QString execQuoted(const QString &path) {
    QString escaped;
    for (const QChar c : path) {
        if (c == u'"' || c == u'`' || c == u'$' || c == u'\\') {
            escaped += u'\\';
        }
        escaped += c;
    }
    return u"\""_s + escaped + u"\""_s;
}
#endif

} // namespace

Preferences::Preferences(QObject *parent)
    : Preferences(std::make_unique<QSettings>(),
                  QDir(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)).filePath(u"autostart"_s),
                  QCoreApplication::applicationFilePath(), parent) {}

Preferences::Preferences(std::unique_ptr<QSettings> settings, QString autostartDir, QString executable,
                         QObject *parent)
    : QObject(parent), m_settings(std::move(settings)), m_autostartDir(std::move(autostartDir)),
      m_executable(std::move(executable)) {}

Preferences::~Preferences() = default;

bool Preferences::notifyBlocks() const {
    return m_settings->value(kNotifyBlocks, false).toBool();
}

void Preferences::setNotifyBlocks(bool on) {
    if (on == notifyBlocks()) {
        return;
    }
    m_settings->setValue(kNotifyBlocks, on);
    emit changed();
}

bool Preferences::welcomed() const {
    return m_settings->value(kWelcomed, false).toBool();
}

void Preferences::setWelcomed(bool shown) {
    m_settings->setValue(kWelcomed, shown);
}

void Preferences::setMoat(const QString &path, const QString &version) {
    if (path == m_moatPath && version == m_moatVersion) {
        return;
    }
    m_moatPath = path;
    m_moatVersion = version;
    emit changed();
}

// MARK: - Start at login

bool Preferences::canStartAtLogin() {
#if defined(Q_OS_WIN) || (defined(Q_OS_UNIX) && !defined(Q_OS_MACOS))
    return true;
#else
    return false; // the macOS app has its own Login Items switch
#endif
}

QString Preferences::autostartFile() const {
    return QDir(m_autostartDir).filePath(kEntryName);
}

bool Preferences::startAtLogin() const {
#ifdef Q_OS_WIN
    return QSettings(kRunKey, QSettings::NativeFormat).contains(kRunValue);
#else
    return QFile::exists(autostartFile());
#endif
}

void Preferences::setStartAtLogin(bool on) {
    if (!canStartAtLogin() || on == startAtLogin()) {
        return;
    }
    m_startAtLoginError.clear();
#ifdef Q_OS_WIN
    QSettings run(kRunKey, QSettings::NativeFormat);
    if (on) {
        run.setValue(kRunValue, u"\"%1\""_s.arg(QDir::toNativeSeparators(m_executable)));
    } else {
        run.remove(kRunValue);
    }
    run.sync();
    if (run.status() != QSettings::NoError) {
        m_startAtLoginError = u"Windows did not save the change."_s;
    }
#else
    if (on) {
        QSaveFile entry(autostartFile());
        const QByteArray text = u"[Desktop Entry]\n"
                                u"Type=Application\n"
                                u"Name=MoatBar\n"
                                u"Comment=See what OpenMoat does for your coding agents. Read-only.\n"
                                u"Exec=%1\n"
                                u"Icon=dev.openmoat.moatbar\n"
                                u"Terminal=false\n"
                                u"X-GNOME-Autostart-enabled=true\n"_s.arg(execQuoted(m_executable))
                                    .toUtf8();
        if (!QDir().mkpath(m_autostartDir) || !entry.open(QIODevice::WriteOnly) || entry.write(text) < 0 ||
            !entry.commit()) {
            m_startAtLoginError = u"Couldn't write %1"_s.arg(autostartFile());
        }
    } else if (!QFile::remove(autostartFile())) {
        m_startAtLoginError = u"Couldn't remove %1"_s.arg(autostartFile());
    }
#endif
    emit changed();
}

} // namespace moatbar
