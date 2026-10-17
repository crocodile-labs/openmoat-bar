#pragma once

#include "core/Models.hpp"

#include <QVariantMap>

#include <optional>

namespace moatbar {

/// `deny`, `ask`, `deferred`, `allow`: how QML names a verdict.
[[nodiscard]] QString verdictKey(Verdict verdict);
[[nodiscard]] std::optional<Verdict> verdictFromKey(QStringView key);

/// One call as a list row: what ran, the rule, the agent, the folder, the time.
[[nodiscard]] QVariantMap eventRowMap(const Event &event, const QString &agentName);

/// One call in full, for Decision.qml.
[[nodiscard]] QVariantMap decisionMap(const Event &event, const QString &agentName);

} // namespace moatbar
