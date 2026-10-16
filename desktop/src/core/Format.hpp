#pragma once

#include <QDateTime>
#include <QString>

namespace moatbar::Format {

/// The time of day in the person's locale, e.g. `14:05` or `2:05 PM`.
[[nodiscard]] QString clock(const QDateTime &time);

/// `just now`, `12 min ago`, then the clock time: what the macOS menu shows.
[[nodiscard]] QString relative(const QDateTime &time, const QDateTime &now);

/// `path` with the home folder written as `~`.
[[nodiscard]] QString shortPath(const QString &path, const QString &home);

/// One line, at most `length` characters, ending in `…` when cut.
[[nodiscard]] QString oneLine(const QString &text, qsizetype length);

/// A count with the locale's digit grouping.
[[nodiscard]] QString count(qint64 n);

} // namespace moatbar::Format
