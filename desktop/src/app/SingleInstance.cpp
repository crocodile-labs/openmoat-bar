#include "app/SingleInstance.hpp"

#include <QCryptographicHash>
#include <QDir>
#include <QLocalSocket>

using namespace Qt::StringLiterals;

namespace moatbar {
namespace {

/// The longest request line read from the socket.
constexpr qint64 kMaxRequest = 32;

} // namespace

SingleInstance::SingleInstance(QString name, QObject *parent) : QObject(parent), m_name(std::move(name)) {
    // Only this user's processes can connect.
    m_server.setSocketOptions(QLocalServer::UserAccessOption);
    connect(&m_server, &QLocalServer::newConnection, this, [this] {
        while (QLocalSocket *socket = m_server.nextPendingConnection()) {
            connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            connect(socket, &QLocalSocket::readyRead, this, [this, socket] {
                if (!socket->canReadLine() && socket->bytesAvailable() < kMaxRequest) {
                    return; // wait for the rest of the line
                }
                const QString request = QString::fromUtf8(socket->readLine(kMaxRequest)).trimmed();
                socket->disconnectFromServer();
                if (isRequest(request)) {
                    emit requested(request);
                }
            });
        }
    });
}

QString SingleInstance::defaultName() {
    // Per user: the home folder's hash, so the name stays short and has no path in it.
    const QByteArray hash = QCryptographicHash::hash(QDir::homePath().toUtf8(), QCryptographicHash::Sha256).toHex();
    return u"dev.openmoat.moatbar-"_s + QString::fromLatin1(hash.left(16));
}

bool SingleInstance::isRequest(const QString &text) {
    return text == u"show" || text == u"activity" || text == u"settings" || text == u"quit";
}

bool SingleInstance::sendToRunning(const QString &request, int timeoutMs) const {
    QLocalSocket socket;
    socket.connectToServer(m_name);
    if (!socket.waitForConnected(timeoutMs)) {
        return false;
    }
    socket.write(QByteArray(request.toUtf8() + '\n'));
    return socket.waitForBytesWritten(timeoutMs);
}

bool SingleInstance::listen() {
    if (m_server.listen(m_name)) {
        return true;
    }
    // A socket left behind by a MoatBar that crashed: nothing answers on it.
    if (m_server.serverError() == QAbstractSocket::AddressInUseError && !sendToRunning(u"ping"_s, 300)) {
        QLocalServer::removeServer(m_name);
        return m_server.listen(m_name);
    }
    return false;
}

} // namespace moatbar
