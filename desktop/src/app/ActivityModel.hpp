#pragma once

#include "core/ActivityFilter.hpp"
#include "core/MoatClient.hpp"

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <optional>

namespace moatbar {

/// The Activity window: every call in a time window (today, 7 days, 30 days),
/// filtered by agent, verdict and rule, one call in full, and an export as
/// JSON lines. Reads moat off the GUI thread; read-only like the rest.
class ActivityModel final : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QStringList windowTitles READ windowTitles CONSTANT)
    Q_PROPERTY(int windowIndex READ windowIndex WRITE setWindowIndex NOTIFY changed)
    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY changed)
    Q_PROPERTY(QString verdict READ verdict WRITE setVerdict NOTIFY changed)
    Q_PROPERTY(QString rule READ rule WRITE setRule NOTIFY changed)
    Q_PROPERTY(QVariantList agents READ agents NOTIFY changed)
    Q_PROPERTY(QVariantList verdictCounts READ verdictCounts NOTIFY changed)
    Q_PROPERTY(QVariantList topRules READ topRules NOTIFY changed)
    Q_PROPERTY(QString sessionsText READ sessionsText NOTIFY changed)
    Q_PROPERTY(QVariantList rows READ rows NOTIFY changed)
    Q_PROPERTY(QString rowsNote READ rowsNote NOTIFY changed)
    Q_PROPERTY(QString selectedId READ selectedId WRITE setSelectedId NOTIFY changed)
    Q_PROPERTY(QVariantMap selected READ selected NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString exportNote READ exportNote NOTIFY changed)

public:
    /// Most rows the list shows; counts and the export cover every match.
    static constexpr int kRowLimit = 500;

    explicit ActivityModel(QObject *parent = nullptr);

    /// Show these events without reading moat (tests, screenshots).
    void setData(const StatusReport &status, std::vector<Event> events);

    [[nodiscard]] int revision() const noexcept { return m_revision; }
    [[nodiscard]] static QStringList windowTitles();
    [[nodiscard]] int windowIndex() const noexcept { return static_cast<int>(m_window); }
    void setWindowIndex(int index);
    [[nodiscard]] QString host() const { return m_filter.host; }
    void setHost(const QString &host);
    [[nodiscard]] QString verdict() const;
    void setVerdict(const QString &verdict);
    [[nodiscard]] QString rule() const { return m_filter.rule; }
    void setRule(const QString &rule);

    [[nodiscard]] QVariantList agents() const;
    [[nodiscard]] QVariantList verdictCounts() const;
    [[nodiscard]] QVariantList topRules() const;
    [[nodiscard]] QString sessionsText() const;
    [[nodiscard]] QVariantList rows() const;
    [[nodiscard]] QString rowsNote() const;
    [[nodiscard]] QString selectedId() const { return m_selectedId; }
    void setSelectedId(const QString &id);
    [[nodiscard]] QVariantMap selected() const;
    [[nodiscard]] bool loading() const noexcept { return m_loading; }
    [[nodiscard]] QString error() const { return m_error; }
    [[nodiscard]] QString exportNote() const { return m_exportNote; }

    /// Every call the filter matches (not only the rows shown), newest first.
    [[nodiscard]] std::vector<Event> matches() const { return m_filter.apply(m_snapshot.events); }

    /// Read the current window from moat.
    Q_INVOKABLE void load();
    /// Ask where to save, then write the matching calls as JSON lines.
    Q_INVOKABLE void exportRows();
    /// Toggle a rule from the sidebar.
    Q_INVOKABLE void toggleRule(const QString &rule) { setRule(m_filter.rule == rule ? QString{} : rule); }

signals:
    void changed();

private:
    void apply(Result<Snapshot> result, int generation);
    void filterChanged();
    void selectFirstIfGone();
    [[nodiscard]] QString agentName(const QString &host) const;

    Snapshot m_snapshot;
    TimeWindow m_window = TimeWindow::Today;
    ActivityFilter m_filter;
    QString m_selectedId;
    bool m_loading = false;
    QString m_error;
    QString m_exportNote;
    int m_generation = 0;
    int m_revision = 0;
};

} // namespace moatbar
