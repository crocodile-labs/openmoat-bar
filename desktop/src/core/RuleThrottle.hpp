#pragma once

#include <QDateTime>
#include <QHash>
#include <QString>

#include <chrono>

namespace moatbar {

/// Limits block notifications to one per rule per period, so a loop that hits
/// the same rule does not flood the screen. The same as the macOS app's.
class RuleThrottle {
public:
    explicit RuleThrottle(std::chrono::seconds period = std::chrono::minutes{10}) : m_period(period) {}

    /// Whether a notification for `rule` may go out now; records it if so.
    bool allow(const QString &rule, const QDateTime &now = QDateTime::currentDateTimeUtc()) {
        const auto last = m_lastSent.constFind(rule);
        if (last != m_lastSent.constEnd() && last->secsTo(now) < m_period.count()) {
            return false;
        }
        m_lastSent.insert(rule, now);
        return true;
    }

private:
    std::chrono::seconds m_period;
    QHash<QString, QDateTime> m_lastSent;
};

} // namespace moatbar
