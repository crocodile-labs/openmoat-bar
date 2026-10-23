#include "core/Models.hpp"
#include "core/Result.hpp"

using namespace Qt::StringLiterals;

namespace moatbar {

QString MoatError::message() const {
    switch (kind) {
    case Kind::NotInstalled:
        return u"OpenMoat isn't installed"_s;
    case Kind::TimedOut:
        return u"openmoat %1 took too long"_s.arg(command);
    case Kind::Failed:
        return u"openmoat %1: %2"_s.arg(command, detail);
    case Kind::Unreadable:
        return u"openmoat %1 gave output OpenMoat Bar can't read. Update OpenMoat."_s.arg(command);
    }
    return {};
}

Level levelFromWire(QStringView wire) noexcept {
    if (wire == u"hook-and-os-sandbox") return Level::HookAndOsSandbox;
    if (wire == u"hook-only") return Level::HookOnly;
    if (wire == u"not-protected") return Level::NotProtected;
    if (wire == u"not-set-up") return Level::NotSetUp;
    if (wire == u"not-found") return Level::NotFound;
    return Level::Unknown;
}

QString levelLabel(Level level) {
    switch (level) {
    case Level::HookAndOsSandbox: return u"Hook + sandbox"_s;
    case Level::HookOnly: return u"Hook only"_s;
    case Level::NotProtected: return u"Not protected"_s;
    case Level::NotSetUp: return u"Not set up"_s;
    case Level::NotFound: return u"Not installed"_s;
    case Level::Unknown: return u"Unknown"_s;
    }
    return {};
}

Verdict verdictFromWire(QStringView wire) noexcept {
    if (wire == u"deny") return Verdict::Deny;
    if (wire == u"ask") return Verdict::Ask;
    if (wire == u"allow") return Verdict::Allow;
    return Verdict::Deferred;
}

QString verdictTitle(Verdict verdict) {
    switch (verdict) {
    case Verdict::Deny: return u"Blocked"_s;
    case Verdict::Ask: return u"Asked"_s;
    case Verdict::Deferred: return u"Left to your agent"_s;
    case Verdict::Allow: return u"Allowed"_s;
    }
    return {};
}

QString verdictSubtitle(Verdict verdict) {
    switch (verdict) {
    case Verdict::Deny: return u"Stopped, with the rule and the reason"_s;
    case Verdict::Ask: return u"OpenMoat asked a person"_s;
    case Verdict::Deferred: return u"No rule: the agent's own prompt decided"_s;
    case Verdict::Allow: return u"Normal work ran"_s;
    }
    return {};
}

QString Action::display() const {
    switch (kind) {
    case Kind::Shell: return target;
    case Kind::ForeignShell: return u"%1: %2"_s.arg(qualifier, target);
    case Kind::FsRead: return u"Read "_s + target;
    case Kind::FsWrite: return u"Write "_s + target;
    case Kind::Net: return u"Connect to "_s + target;
    case Kind::Fetch: return u"Fetch "_s + target;
    case Kind::WebSearch: return u"Search “%1”"_s.arg(target);
    case Kind::UnknownTool: return target;
    case Kind::Patch:
        return targets.size() == 1 ? u"Patch "_s + targets.first() : u"Patch %1 files"_s.arg(targets.size());
    case Kind::ReadFiles:
        return targets.size() == 1 ? u"Read "_s + targets.first() : u"Read %1 files"_s.arg(targets.size());
    case Kind::McpTool: return target;
    case Kind::Other: return wireKind;
    }
    return {};
}

std::optional<QString> Action::shellCommand() const {
    if (kind == Kind::Shell) {
        return target;
    }
    return std::nullopt;
}

std::optional<QString> Event::rule() const {
    if (rules.isEmpty()) {
        return std::nullopt;
    }
    return rules.first();
}

std::optional<QString> Event::reason() const {
    if (reasons.isEmpty()) {
        return std::nullopt;
    }
    return reasons.first();
}

QString ProxyState::label() const {
    switch (kind) {
    case Kind::NotInstalled: return u"Not installed"_s;
    case Kind::Stopped: return u"Stopped"_s;
    case Kind::Running: return u"Running"_s;
    case Kind::DriftBlocked: return u"Stopped after a watched file changed"_s;
    case Kind::Crashlooping: return u"Keeps crashing"_s;
    case Kind::Unknown: return details;
    }
    return {};
}

QString timeWindowWire(TimeWindow window) {
    switch (window) {
    case TimeWindow::Today: return u"today"_s;
    case TimeWindow::SevenDays: return u"7d"_s;
    case TimeWindow::ThirtyDays: return u"30d"_s;
    }
    return {};
}

QString timeWindowTitle(TimeWindow window) {
    switch (window) {
    case TimeWindow::Today: return u"Today"_s;
    case TimeWindow::SevenDays: return u"7 days"_s;
    case TimeWindow::ThirtyDays: return u"30 days"_s;
    }
    return {};
}

} // namespace moatbar
