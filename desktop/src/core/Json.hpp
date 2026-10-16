#pragma once

// Decoding moat's JSON. Each function takes the bytes moat printed and the
// subcommand that printed them (for the error message). Values a newer moat
// adds decode to safe defaults: a level is never "protected", a verdict is
// never "allowed" or "blocked".

#include "core/Models.hpp"
#include "core/Result.hpp"

#include <QByteArray>

namespace moatbar::json {

[[nodiscard]] Result<StatusReport> parseStatus(const QByteArray &bytes);
[[nodiscard]] Result<std::vector<Event>> parseEvents(const QByteArray &bytes);
[[nodiscard]] Result<Summary> parseSummary(const QByteArray &bytes);
[[nodiscard]] Result<ProxyState> parseProxy(const QByteArray &bytes);

/// `moat 0.5.3 (OpenMoat)` → `0.5.3`.
[[nodiscard]] Result<QString> parseVersion(const QByteArray &bytes);

} // namespace moatbar::json
