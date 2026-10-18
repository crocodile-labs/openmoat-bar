#pragma once

#include "core/MoatClient.hpp"

#include <QDateTime>
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

#include <functional>
#include <optional>

namespace moatbar {

/// What the Quick View shows, as plain lists and maps for QML: the same
/// content and order as the macOS menu (header, problems, Today, Blocked /
/// Asked / Left to your agent / Allowed, agents, security checks). Read-only:
/// the only things it does are copy text, open a docs page and ask for a refresh.
class QuickViewModel final : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QVariantMap unavailable READ unavailable NOTIFY changed)
    Q_PROPERTY(QVariantList tabs READ tabs NOTIFY changed)
    Q_PROPERTY(QString selectedHost READ selectedHost WRITE setSelectedHost NOTIFY changed)
    Q_PROPERTY(QVariantMap header READ header NOTIFY changed)
    Q_PROPERTY(QVariantList problems READ problems NOTIFY changed)
    Q_PROPERTY(QVariantList notices READ notices NOTIFY changed)
    Q_PROPERTY(QVariantMap today READ today NOTIFY changed)
    Q_PROPERTY(QVariantList verdicts READ verdicts NOTIFY changed)
    Q_PROPERTY(QVariantList agents READ agents NOTIFY changed)
    Q_PROPERTY(QVariantMap agentDetail READ agentDetail NOTIFY changed)
    Q_PROPERTY(QVariantList sessions READ sessions NOTIFY changed)
    Q_PROPERTY(QString proxy READ proxy NOTIFY changed)
    Q_PROPERTY(QVariantList checks READ checks NOTIFY changed)
    Q_PROPERTY(QString checksHint READ checksHint NOTIFY changed)
    Q_PROPERTY(QString refreshState READ refreshState NOTIFY refreshChanged)
    Q_PROPERTY(QString refreshText READ refreshText NOTIFY refreshChanged)
    Q_PROPERTY(QString doctorCommand READ doctorCommand CONSTANT)
    Q_PROPERTY(int listLimit READ listLimit CONSTANT)

public:
    explicit QuickViewModel(QObject *parent = nullptr);

    /// Show this read of moat. `now` is when "x min ago" is counted from.
    void setData(const std::optional<Snapshot> &snapshot, const std::optional<MoatError> &error,
                 const QDateTime &now = QDateTime::currentDateTime());
    /// What Refresh does; without it the Refresh row does nothing.
    void setRefreshHandler(std::function<void()> handler) { m_refreshHandler = std::move(handler); }
    /// After the read Refresh asked for: says so on the Refresh row for a few seconds.
    void refreshFinished(const std::optional<MoatError> &error);

    [[nodiscard]] int revision() const noexcept { return m_revision; }
    [[nodiscard]] bool available() const noexcept { return m_snapshot.has_value(); }
    [[nodiscard]] QVariantMap unavailable() const;
    [[nodiscard]] QVariantList tabs() const;
    [[nodiscard]] QString selectedHost() const { return m_selectedHost; }
    void setSelectedHost(const QString &host);
    [[nodiscard]] QVariantMap header() const;
    [[nodiscard]] QVariantList problems() const;
    /// A policy update to look at and pinned files that changed (OpenMoat 0.5.7+),
    /// on every tab: they are about OpenMoat itself.
    [[nodiscard]] QVariantList notices() const;
    [[nodiscard]] QVariantMap today() const;
    [[nodiscard]] QVariantList verdicts() const;
    [[nodiscard]] QVariantList agents() const;
    [[nodiscard]] QVariantMap agentDetail() const;
    [[nodiscard]] QVariantList sessions() const;
    [[nodiscard]] QString proxy() const;
    [[nodiscard]] QVariantList checks() const;
    [[nodiscard]] QString checksHint() const;
    [[nodiscard]] QString refreshState() const { return m_refreshState; }
    [[nodiscard]] QString refreshText() const { return m_refreshText; }
    [[nodiscard]] QString doctorCommand() const;
    [[nodiscard]] static int listLimit() noexcept { return kListLimit; }

    /// Calls with one verdict (`deny`, `ask`, `deferred`, `allow`) for the
    /// selected tab, newest first, at most `listLimit`.
    // (No [[nodiscard]] on invokables: moc does not take attributes there.)
    Q_INVOKABLE QVariantList events(const QString &verdict) const;
    /// How many calls `events(verdict)` left out.
    Q_INVOKABLE int moreEvents(const QString &verdict) const;
    /// One call in full, by event id; empty when moat no longer reports it.
    Q_INVOKABLE QVariantMap decision(const QString &id) const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE static void copy(const QString &text);
    /// `home`, `blocked`, `check`, `quickstart` or `limits`.
    Q_INVOKABLE static void openDocs(const QString &page);
    Q_INVOKABLE static void reportWrongBlock(const QString &rule);
    /// The Activity window, showing one verdict (`deny`…) or, for "", everything.
    Q_INVOKABLE void openActivity(const QString &verdict) { emit activityRequested(verdict); }
    Q_INVOKABLE void openSettings() { emit settingsRequested(); }
    /// A detail page (`allowed`, `secrets`, `checks`) was opened: read moat for it.
    Q_INVOKABLE void openDetails(const QString &page) { emit detailsRequested(page); }
    Q_INVOKABLE void about() { emit aboutRequested(); }
    Q_INVOKABLE void quit() { emit quitRequested(); }
    /// The Quick View closed: what it showed has been seen.
    Q_INVOKABLE void closed() { emit viewClosed(); }

signals:
    void changed();
    void refreshChanged();
    void activityRequested(const QString &verdict);
    void settingsRequested();
    void detailsRequested(const QString &page);
    void aboutRequested();
    void quitRequested();
    void viewClosed();

private:
    static constexpr int kListLimit = 25;

    [[nodiscard]] QStringView host() const { return m_selectedHost; }
    [[nodiscard]] QString agentName(const QString &host) const;
    void setRefresh(const QString &state, const QString &text);

    std::optional<Snapshot> m_snapshot;
    std::optional<MoatError> m_error;
    QDateTime m_now;
    QString m_selectedHost;
    int m_revision = 0;
    std::function<void()> m_refreshHandler;
    QString m_refreshState = QStringLiteral("idle");
    QString m_refreshText;
    QTimer m_settle;
};

} // namespace moatbar
