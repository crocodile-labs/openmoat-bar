#include "app/ActivityModel.hpp"
#include "app/EventViews.hpp"
#include "core/Format.hpp"
#include "core/Json.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QFileDialog>
#include <QPointer>
#include <QSaveFile>
#include <QThreadPool>

#include <algorithm>
#include <memory>

using namespace Qt::StringLiterals;
using namespace std::chrono_literals;

namespace moatbar {
namespace {

constexpr std::array kWindows{TimeWindow::Today, TimeWindow::SevenDays, TimeWindow::ThirtyDays};

/// Thirty days of calls can take moat a while to print.
constexpr auto kReadTimeout = 15s;

Result<Snapshot> readWindow(TimeWindow window) {
    const auto binary = MoatClient::locate();
    if (!binary) {
        return MoatError{MoatError::Kind::NotInstalled, {}, {}};
    }
    const MoatClient client(*binary, std::make_shared<ProcessRunner>(), kReadTimeout);
    auto status = client.status();
    if (!status) {
        return status.error();
    }
    auto events = client.events(window);
    if (!events) {
        return events.error();
    }
    return Snapshot{std::move(status).value(), std::move(events).value(), std::nullopt, std::nullopt,
                    QDateTime::currentDateTime()};
}

} // namespace

ActivityModel::ActivityModel(QObject *parent) : QObject(parent) {}

void ActivityModel::setData(const StatusReport &status, std::vector<Event> events) {
    ++m_generation; // a read still running must not replace this
    m_loading = false;
    m_error.clear();
    m_snapshot = Snapshot{status, std::move(events), std::nullopt, std::nullopt, QDateTime::currentDateTime()};
    selectFirstIfGone();
    ++m_revision;
    emit changed();
}

QStringList ActivityModel::windowTitles() {
    QStringList out;
    for (const TimeWindow window : kWindows) {
        out << timeWindowTitle(window);
    }
    return out;
}

void ActivityModel::setWindowIndex(int index) {
    const auto clamped = static_cast<std::size_t>(std::clamp(index, 0, static_cast<int>(kWindows.size()) - 1));
    if (kWindows[clamped] == m_window) {
        return;
    }
    m_window = kWindows[clamped];
    ++m_revision;
    emit changed();
    load();
}

void ActivityModel::setHost(const QString &host) {
    if (host == m_filter.host) {
        return;
    }
    m_filter.host = host;
    filterChanged();
}

QString ActivityModel::verdict() const {
    return m_filter.verdict ? verdictKey(*m_filter.verdict) : QString{};
}

void ActivityModel::setVerdict(const QString &verdict) {
    const auto which = verdictFromKey(verdict);
    if (which == m_filter.verdict) {
        return;
    }
    m_filter.verdict = which;
    // A new verdict starts at its newest call, as on macOS.
    m_selectedId.clear();
    filterChanged();
}

void ActivityModel::setRule(const QString &rule) {
    if (rule == m_filter.rule) {
        return;
    }
    m_filter.rule = rule;
    filterChanged();
}

void ActivityModel::setSelectedId(const QString &id) {
    if (id == m_selectedId) {
        return;
    }
    m_selectedId = id;
    ++m_revision;
    emit changed();
}

void ActivityModel::filterChanged() {
    selectFirstIfGone();
    ++m_revision;
    emit changed();
}

void ActivityModel::selectFirstIfGone() {
    const auto shown = matches();
    const bool stillShown = std::ranges::any_of(shown, [this](const Event &e) { return e.id == m_selectedId; });
    if (!stillShown) {
        m_selectedId = shown.empty() ? QString{} : shown.front().id;
    }
}

QString ActivityModel::agentName(const QString &host) const {
    return m_snapshot.agentName(host);
}

// MARK: - What the window shows

QVariantList ActivityModel::agents() const {
    QVariantList out;
    for (const Protection &agent : m_snapshot.installedAgents()) {
        out << QVariantMap{{u"host"_s, agent.host}, {u"name"_s, agent.name}};
    }
    return out;
}

QVariantList ActivityModel::verdictCounts() const {
    const VerdictCounts counts = m_snapshot.counts(m_filter.host);
    QVariantList out;
    for (const Verdict verdict : kVerdicts) {
        out << QVariantMap{
            {u"key"_s, verdictKey(verdict)},
            {u"title"_s, verdictTitle(verdict)},
            {u"countText"_s, Format::count(counts[verdict])},
        };
    }
    out << QVariantMap{
        {u"key"_s, QString{}},
        {u"title"_s, u"Everything"_s},
        {u"countText"_s, Format::count(counts.total())},
    };
    return out;
}

QVariantList ActivityModel::topRules() const {
    QVariantList out;
    const auto rules = m_snapshot.topRules(m_filter.host);
    for (std::size_t i = 0; i < std::min<std::size_t>(rules.size(), 8); ++i) {
        out << QVariantMap{{u"rule"_s, rules[i].rule}, {u"countText"_s, Format::count(rules[i].count)}};
    }
    return out;
}

QString ActivityModel::sessionsText() const {
    const auto n = m_snapshot.sessions(m_filter.host).size();
    return n == 1 ? u"1 session"_s : u"%1 sessions"_s.arg(n);
}

QVariantList ActivityModel::rows() const {
    QVariantList out;
    const auto shown = matches();
    for (std::size_t i = 0; i < std::min<std::size_t>(shown.size(), kRowLimit); ++i) {
        out << eventRowMap(shown[i], agentName(shown[i].host));
    }
    return out;
}

QString ActivityModel::rowsNote() const {
    const auto n = static_cast<qint64>(matches().size());
    if (n > kRowLimit) {
        return u"The newest %1 of %2 calls. Export saves them all."_s.arg(kRowLimit).arg(Format::count(n));
    }
    return n == 1 ? u"1 call"_s : u"%1 calls"_s.arg(Format::count(n));
}

QVariantMap ActivityModel::selected() const {
    const auto it = std::ranges::find(m_snapshot.events, m_selectedId, &Event::id);
    if (m_selectedId.isEmpty() || it == m_snapshot.events.end()) {
        return {};
    }
    return decisionMap(*it, agentName(it->host));
}

// MARK: - Reading and export

void ActivityModel::load() {
    const int generation = ++m_generation;
    m_loading = true;
    ++m_revision;
    emit changed();
    QThreadPool::globalInstance()->start([guard = QPointer<ActivityModel>(this), window = m_window, generation] {
        auto result = std::make_shared<Result<Snapshot>>(readWindow(window));
        QMetaObject::invokeMethod(
            QCoreApplication::instance(),
            [guard, result, generation] {
                if (guard) {
                    guard->apply(std::move(*result), generation);
                }
            },
            Qt::QueuedConnection);
    });
}

void ActivityModel::apply(Result<Snapshot> result, int generation) {
    if (generation != m_generation) {
        return; // a newer read or setData came after this one
    }
    m_loading = false;
    if (result) {
        m_snapshot = std::move(result).value();
        m_error.clear();
        selectFirstIfGone();
    } else {
        m_error = result.error().message();
    }
    ++m_revision;
    emit changed();
}

void ActivityModel::exportRows() {
    const auto calls = matches();
    const QString suggested = QDir::home().filePath(u"moatbar-activity-%1.jsonl"_s.arg(timeWindowWire(m_window)));
    const QString path =
        QFileDialog::getSaveFileName(nullptr, u"Export calls"_s, suggested, u"JSON lines (*.jsonl);;All files (*)"_s);
    if (path.isEmpty()) {
        return;
    }
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly) && file.write(json::toJsonLines(calls)) >= 0 && file.commit()) {
        m_exportNote = u"Saved %1 calls to %2"_s.arg(calls.size()).arg(QDir::toNativeSeparators(path));
    } else {
        m_exportNote = u"Couldn't save: %1"_s.arg(file.errorString());
    }
    ++m_revision;
    emit changed();
}

} // namespace moatbar
