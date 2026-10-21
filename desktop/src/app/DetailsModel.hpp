#pragma once

#include "core/MoatClient.hpp"

#include <QDateTime>
#include <QMap>
#include <QObject>
#include <QVariantMap>

#include <optional>

namespace moatbar {

/// The Quick View's detail pages, as plain maps for QML: What you allowed,
/// Secrets and every `openmoat doctor` check. Each page map has `state`
/// (`loading`, `loaded`, `note` for an older moat, `failed`) and `note`.
/// Reads moat off the GUI thread; read-only like the rest: every change is a
/// command to copy.
class DetailsModel final : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QVariantMap allowed READ allowed NOTIFY changed)
    Q_PROPERTY(QVariantMap secrets READ secrets NOTIFY changed)
    Q_PROPERTY(QVariantMap checks READ checks NOTIFY changed)
    Q_PROPERTY(QString updateNote READ updateNote NOTIFY changed)

public:
    explicit DetailsModel(QObject *parent = nullptr);

    /// Show these screens without reading moat (tests, screenshots).
    void setData(Details details, const QDateTime &now = QDateTime::currentDateTime());
    /// From the tray's last read: agent names for session grants, and whether
    /// moat sends update notices.
    void setStatus(const StatusReport &status);

    [[nodiscard]] int revision() const noexcept { return m_revision; }
    [[nodiscard]] bool loading() const noexcept { return m_loading; }
    [[nodiscard]] QVariantMap allowed() const;
    [[nodiscard]] QVariantMap secrets() const;
    [[nodiscard]] QVariantMap checks() const;
    [[nodiscard]] QString updateNote() const { return m_updateNote; }

    /// Read the three screens from moat.
    Q_INVOKABLE void load();

signals:
    void changed();

private:
    void apply(Result<Details> result, int generation);

    std::optional<Details> m_details;
    std::optional<QString> m_error; ///< moat not found at all
    QDateTime m_now;
    QMap<QString, QString> m_agentNames;
    QString m_updateNote;
    bool m_loading = false;
    int m_generation = 0;
    int m_revision = 0;
};

} // namespace moatbar
