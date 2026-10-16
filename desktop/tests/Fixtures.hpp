#pragma once

#include "core/MoatClient.hpp"

#include <QDir>
#include <QFile>
#include <QTest>

#include <map>
#include <utility>

namespace moatbar::test {

/// Bytes of `Tests/MoatBarCoreTests/Fixtures/<name>.json`.
inline QByteArray fixture(const QString &name) {
    QFile file(QString::fromUtf8(MOATBAR_FIXTURES_DIR) + u'/' + name + QStringLiteral(".json"));
    if (!file.open(QIODevice::ReadOnly)) {
        qFatal("missing fixture %s", qPrintable(name));
    }
    return file.readAll();
}

/// Returns canned output per moat subcommand and records what was run.
class StubRunner final : public CommandRunner {
public:
    void stub(const QString &command, Result<QByteArray> output) {
        outputs.insert_or_assign(command, std::move(output));
    }

    Result<QByteArray> run(const QString & /*program*/, const QStringList &arguments,
                           std::chrono::milliseconds /*timeout*/) override {
        calls.append(arguments);
        const QString command = arguments.value(0);
        const auto it = outputs.find(command);
        if (it == outputs.end()) {
            return MoatError{MoatError::Kind::Failed, command, QStringLiteral("no stub")};
        }
        return it->second;
    }

    std::map<QString, Result<QByteArray>> outputs;
    QList<QStringList> calls;
};

} // namespace moatbar::test
