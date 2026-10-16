#include "core/Format.hpp"

#include <QLocale>

using namespace Qt::StringLiterals;

namespace moatbar::Format {

QString clock(const QDateTime &time) {
    return QLocale().toString(time.time(), QLocale::ShortFormat);
}

QString relative(const QDateTime &time, const QDateTime &now) {
    const qint64 seconds = time.secsTo(now);
    if (seconds < 60) {
        return u"just now"_s;
    }
    if (seconds < 3600) {
        return u"%1 min ago"_s.arg(seconds / 60);
    }
    return clock(time);
}

QString shortPath(const QString &path, const QString &home) {
    if (home.isEmpty() || !path.startsWith(home)) {
        return path;
    }
    // Only a whole folder name: /home/al is not the home of /home/alex.
    if (path.size() > home.size() && path[home.size()] != u'/' && path[home.size()] != u'\\') {
        return path;
    }
    return u"~"_s + path.mid(home.size());
}

QString oneLine(const QString &text, qsizetype length) {
    QString line = text.simplified();
    if (length > 1 && line.size() > length) {
        line = line.left(length - 1) + u"…"_s;
    }
    return line;
}

QString count(qint64 n) {
    return QLocale().toString(n);
}

} // namespace moatbar::Format
