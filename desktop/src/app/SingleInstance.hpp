#pragma once

#include <QLocalServer>
#include <QObject>
#include <QString>

namespace moatbar {

/// One OpenMoat Bar per user. The first to start listens on a local socket only
/// that user can open; a later start hands its request ("show", "activity",
/// "settings", "quit") to it and exits. A request only opens or closes
/// OpenMoat Bar's own windows: nothing on the socket reads data or changes anything.
class SingleInstance final : public QObject {
    Q_OBJECT

public:
    /// `name`: the socket, per user by default (tests pass their own).
    explicit SingleInstance(QString name = defaultName(), QObject *parent = nullptr);

    /// Hand `request` to an OpenMoat Bar that is already running. True if one took it.
    [[nodiscard]] bool sendToRunning(const QString &request, int timeoutMs = 1000) const;
    /// Become the running OpenMoat Bar. False if another one is listening already.
    bool listen();

    [[nodiscard]] static QString defaultName();
    /// The socket of the same app under its old name, MoatBar (0.2 and earlier).
    [[nodiscard]] static QString legacyName();
    /// The requests a later start may send.
    [[nodiscard]] static bool isRequest(const QString &text);

signals:
    void requested(const QString &request);

private:
    QString m_name;
    QLocalServer m_server;
};

} // namespace moatbar
