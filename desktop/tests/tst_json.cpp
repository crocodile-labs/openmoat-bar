#include "Fixtures.hpp"
#include "core/Json.hpp"
#include "core/Text.hpp"

#include <algorithm>

using namespace Qt::StringLiterals;
using namespace moatbar;
using moatbar::test::fixture;

class TestJson : public QObject {
    Q_OBJECT

private slots:
    void statusDecodesEveryLevel() {
        const auto status = json::parseStatus(fixture(u"status"_s));
        QVERIFY(status.ok());
        const auto &agents = status.value().agents;
        QCOMPARE(agents.size(), std::size_t{3});
        QCOMPARE(agents[0].host, u"claude-code"_s);
        QVERIFY(agents[0].level == Level::HookAndOsSandbox);
        QVERIFY(agents[1].level == Level::HookOnly);
        QVERIFY(agents[2].level == Level::NotFound);
        QCOMPARE(agents[1].reason.value_or(QString{}), u"the sandbox profile is older than the policy"_s);
        QVERIFY(!agents[0].reason.has_value());
    }

    void unknownLevelIsNeverProtected() {
        const auto status = json::parseStatus(fixture(u"status-unprotected"_s));
        QVERIFY(status.ok());
        QVERIFY(status.value().agents[2].level == Level::Unknown);
        QVERIFY(!isHooked(status.value().agents[2].level));
    }

    void eventsDecodeActionsVerdictsAndIds() {
        const auto events = json::parseEvents(fixture(u"show-today"_s));
        QVERIFY(events.ok());
        const auto &list = events.value();
        QCOMPARE(list.size(), std::size_t{8});
        QCOMPARE(list[0].id, u"1a"_s);
        QCOMPARE(list[0].action->shellCommand().value_or(QString{}), u"git status --short"_s);
        QVERIFY(list[2].action->kind == Action::Kind::FsRead);
        QCOMPARE(list[2].display(), u"Read /Users/you/.ssh/id_ed25519"_s);
        QVERIFY(list[3].verdict == Verdict::Deferred);
        QCOMPARE(list[4].rule().value_or(QString{}), u"secrets-paths"_s);
        QCOMPARE(list[4].reason().value_or(QString{}), u"secret material: read /Users/you/code/app/.env"_s);
        QVERIFY(list[6].action->kind == Action::Kind::McpTool);
    }

    void eventWithoutActionShowsTheTool() {
        const auto events = json::parseEvents(fixture(u"show-today"_s));
        QVERIFY(events.ok());
        const Event &event = events.value()[7];
        QVERIFY(!event.action.has_value());
        QVERIFY(!event.cwd.has_value());
        QCOMPARE(event.display(), u"TodoWrite"_s);
    }

    void olderAndNewerMoatStillDecode() {
        const auto events = json::parseEvents(fixture(u"show-legacy"_s));
        QVERIFY(events.ok());
        const auto &list = events.value();
        QCOMPARE(list[0].id, u"1f"_s); // integer row ids become hex
        QVERIFY(list[0].verdict == Verdict::Deferred); // never counted as allowed or blocked
        QCOMPARE(list[0].display(), u"Patch 2 files"_s);
        QVERIFY(list[0].reasons.isEmpty());
        QVERIFY(list[1].action->kind == Action::Kind::Other);
        QCOMPARE(list[1].display(), u"frobnicate"_s);
    }

    void reportDecodesRuleTuples() {
        const auto report = json::parseSummary(fixture(u"report-7d"_s));
        QVERIFY(report.ok());
        const Summary &summary = report.value();
        QCOMPARE(summary.total, 8421);
        QCOMPARE(summary.deferred, 1350);
        QCOMPARE(summary.byHost.at(u"codex"_s), 3301);
        QVERIFY(summary.topRules.front() == (RuleCount{u"secrets-paths"_s, 22}));
        QCOMPARE(summary.activeHours, 41);
    }

    void proxyDecodesKnownAndUnknownStates() {
        const auto running = json::parseProxy(fixture(u"proxy-running"_s));
        QVERIFY(running.ok() && running.value().running());
        const auto unknown = json::parseProxy(fixture(u"proxy-unknown"_s));
        QVERIFY(unknown.ok());
        QVERIFY(unknown.value().kind == ProxyState::Kind::Unknown);
        QCOMPARE(unknown.value().label(), u"systemctl --user has no user bus"_s);
    }

    void allowedDecodesRulesGrantsAndRepos() {
        const auto allowed = json::parseAllowed(fixture(u"allowed"_s));
        QVERIFY(allowed.ok());
        const AllowedReport &report = allowed.value();
        QCOMPARE(report.rules.size(), std::size_t{3});
        QCOMPARE(report.rules[0].id, u"approved-1"_s);
        QVERIFY(report.rules[0].patterns == (std::vector<RulePatterns>{{u"shell"_s, {u"npm install"_s}}}));
        QCOMPARE(report.rules[1].reason.value_or(QString{}), u"allowed with moat allow --site"_s);
        QCOMPARE(report.rules[1].patterns.size(), std::size_t{2});
        QCOMPARE(report.rules[1].patterns[0].line(), u"Network: docs.rs, *.docs.rs"_s);
        QCOMPARE(report.rules[1].patterns[1].kind, u"fetch"_s);
        QCOMPARE(report.rules[2].patterns[2].label(), u"MCP tools"_s);
        QCOMPARE(report.sessionGrants.size(), std::size_t{2});
        QCOMPARE(report.sessionGrants[0].what, u"run \"cargo publish --dry-run\""_s);
        QCOMPARE(report.sessionGrants[0].expiresAtMs, std::int64_t{1792072400000});
        QCOMPARE(report.trustedRepos.size(), std::size_t{1});
        QCOMPARE(report.trustedRepos[0].root, u"/Users/you/code/team app"_s);
    }

    void secretsDecodeSourcesAndExposure() {
        const auto list = json::parseSecrets(fixture(u"secret-list"_s));
        QVERIFY(list.ok());
        const auto &secrets = list.value().secrets;
        QCOMPARE(secrets.size(), std::size_t{4});
        QVERIFY(secrets[0].source.kind == SecretSource::Kind::Env);
        QVERIFY(secrets[0].sourceExposed);
        QCOMPARE(secrets[0].line(), u"api.github.com, Authorization header, from the variable GITHUB_TOKEN"_s);
        QVERIFY(secrets[1].source.kind == SecretSource::Kind::File);
        QVERIFY(!secrets[1].sourceExposed);
        QVERIFY(secrets[2].source.kind == SecretSource::Kind::Keychain);
        QCOMPARE(secrets[2].source.account, u"you"_s);
        QVERIFY(secrets[2].plainHttp);
        QVERIFY(secrets[3].source.kind == SecretSource::Kind::Unknown); // a source a newer moat added
    }

    void secretWithoutSourceExposedCountsAsExposed() {
        const auto list = json::parseSecrets(
            QByteArrayLiteral(R"({"secrets": [{"id": "a", "host": "h", "header": "X", "source": {"env": "A"}}]})"));
        QVERIFY(list.ok());
        QVERIFY(list.value().secrets[0].sourceExposed);
    }

    void doctorGroupsByStatusWorstFirst() {
        const auto doctor = json::parseDoctor(fixture(u"doctor"_s));
        QVERIFY(doctor.ok());
        const DoctorReport &report = doctor.value();
        QVERIFY(!report.healthy);
        QCOMPARE(report.problems, 1);
        QCOMPARE(report.checks.size(), std::size_t{7});
        QVERIFY(report.checks[6].status == DoctorStatus::Warning); // unknown status: never fine
        const auto groups = report.groups();
        QCOMPARE(groups.size(), std::size_t{4});
        QVERIFY(groups[0].status == DoctorStatus::Problem);
        QCOMPARE(groups[0].checks.size(), std::size_t{1});
        QCOMPARE(groups[1].checks.size(), std::size_t{2});
        QCOMPARE(groups[3].checks.size(), std::size_t{3});
        QCOMPARE(doctorStatusTitle(groups[1].status), u"Needs a look"_s);
        const DoctorCheck &unnamed = report.checks[3];
        QVERIFY(!unnamed.area.has_value());
        QCOMPARE(unnamed.title(), unnamed.detail);
        QVERIFY(unnamed.subtitle().isEmpty());
    }

    void doctorTextIsUnreadable() {
        QVERIFY(!json::parseDoctor(QByteArrayLiteral("policy  ok\n")).ok());
    }

    void statusDecodesUpdateNotices() {
        const auto status = json::parseStatus(fixture(u"status-notices"_s));
        QVERIFY(status.ok());
        QCOMPARE(status.value().policyUpdate.value_or(QString{}), u"3 changes from the OpenMoat 0.5.7 default"_s);
        QCOMPARE(status.value().lockDrift.size(), 2);
        QVERIFY(status.value().hasUpdateNotices);
        QVERIFY(!MoatRequirement::updateNoticesNote(true).has_value());
    }

    void statusFromOlderMoatHasNoNotices() {
        const auto status = json::parseStatus(fixture(u"status"_s));
        QVERIFY(status.ok());
        QVERIFY(!status.value().policyUpdate.has_value());
        QVERIFY(status.value().lockDrift.isEmpty());
        QVERIFY(!status.value().hasUpdateNotices);
        QCOMPARE(MoatRequirement::updateNoticesNote(false).value_or(QString{}),
                 u"Policy update and changed-file notices need OpenMoat 0.5.7 or later."_s);
        const auto empty = json::parseStatus(QByteArrayLiteral(R"({"agents": [], "policy_update": null, "lock_drift": []})"));
        QVERIFY(empty.ok() && empty.value().hasUpdateNotices && !empty.value().policyUpdate);
    }

    void statusDecodesProjectSettings() {
        const auto status = json::parseStatus(fixture(u"status-project-settings"_s));
        QVERIFY(status.ok());
        const QStringList &lines = status.value().projectSettings;
        QCOMPARE(lines.size(), 2);
        QVERIFY(lines[0].startsWith(u"/Users/you/code/site/.claude/settings.json: `hooks`"_s));
        QVERIFY(status.value().mcpChanges.isEmpty());
        QVERIFY(status.value().hasUpdateNotices);
        // A moat before 0.8.0 sends nothing, so nothing shows.
        const auto older = json::parseStatus(fixture(u"status-mcp"_s));
        QVERIFY(older.ok() && older.value().projectSettings.isEmpty());
    }

    void detailWordsAndCommands() {
        const std::int64_t now = 1792061000000;
        QCOMPARE(DetailsText::endsIn(now + 11400000, now), u"Ends in 3 h 10 min"_s);
        QCOMPARE(DetailsText::endsIn(now + 7200000, now), u"Ends in 2 h"_s);
        QCOMPARE(DetailsText::endsIn(now + 30000, now), u"Ends in 1 min"_s);
        QCOMPARE(DetailsText::endsIn(now - 1, now), u"Ended"_s);
        QCOMPARE(CopyCommands::removeRule(u"approved-1"_s, Shell::Posix), u"openmoat allow --remove approved-1"_s);
        QCOMPARE(CopyCommands::revokeTrust(u"/Users/you/code/team app"_s, Shell::Posix),
                 u"openmoat trust --revoke '/Users/you/code/team app'"_s);
        QCOMPARE(CopyCommands::revokeTrust(u"C:\\Users\\you\\code\\app"_s, Shell::PowerShell),
                 u"openmoat trust --revoke C:\\Users\\you\\code\\app"_s);
        QCOMPARE(CopyCommands::policyUpgrade(), u"openmoat policy upgrade"_s);
    }

    // MARK: - Newer moats: doctor lines, MCP changes, new rules

    void doctorGroupsLikeChecksTogether() {
        const auto doctor = json::parseDoctor(fixture(u"doctor-signed"_s));
        QVERIFY(doctor.ok());
        const auto groups = doctor.value().groups();
        QCOMPARE(groups.size(), std::size_t{4});
        const auto topics = [](const DoctorGroup &group) {
            QStringList out;
            for (const DoctorCheck &check : group.checks) {
                out << doctorTopicLabel(check.topic());
            }
            return out;
        };
        QCOMPARE(topics(groups[0]), (QStringList{u"Pinned files"_s, u"MCP servers"_s, u"MCP servers"_s}));
        QCOMPARE(topics(groups[1]), QStringList{u"Hooks"_s});
        QCOMPARE(topics(groups[2]), (QStringList{u"Policy"_s, u"Audit log"_s, u"Audit log"_s}));
        QCOMPARE(topics(groups[3]), (QStringList{u"Policy"_s, u"Hooks"_s, u"Audit log"_s}));
        QCOMPARE(groups[2].checks[0].title(), u"Repository policy"_s);
        QCOMPARE(groups[2].checks[2].title(), u"Audit anchor"_s);
    }

    void doctorNewLinesAreExplained() {
        const auto doctor = json::parseDoctor(fixture(u"doctor-signed"_s));
        QVERIFY(doctor.ok());
        const auto &checks = doctor.value().checks;
        // A copy, or an empty check (whose asserts then fail) when there is none.
        const auto find = [&checks](QStringView name, QStringView needle = {}) {
            const auto it = std::ranges::find_if(checks, [&](const DoctorCheck &check) {
                return check.name == name && check.detail.contains(needle);
            });
            return it == checks.end() ? DoctorCheck{} : *it;
        };
        const DoctorCheck anchor = find(u"audit anchor");
        QVERIFY(anchor.subtitle().startsWith(u"last made 2026-10-18 09:12:44 UTC (event 1198)"_s));
        QVERIFY(CheckText::hint(anchor).value_or(QString{}).startsWith(u"A copy of the audit log's latest hash"_s));
        QVERIFY(!CheckText::fix(anchor));
        QCOMPARE(CheckText::hint(find(u"repo policy")).value_or(QString{}),
                 u"Signed by alice@example.com, a key you trust, so its allow rules apply too."_s);
        QVERIFY(CheckText::hint(find(u"lock")).value_or(QString{}).startsWith(u"A signed policy pack changed"_s));
        const DoctorCheck hook = find(u"Claude Code", u"onFailure");
        QVERIFY(hook.topic() == DoctorTopic::Hooks);
        QVERIFY(CheckText::hint(hook).value_or(QString{}).contains(u"still runs when the OpenMoat hook crashes"_s));
        QCOMPARE(CheckText::fix(find(u"mcp servers")).value_or(QString{}), u"openmoat mcp accept gh"_s);
        QCOMPARE(CheckText::fix(find(u"mcp tools")).value_or(QString{}), u"openmoat mcp accept docs"_s);
        QCOMPARE(CheckText::hint(find(u"mcp servers")).value_or(QString{}),
                 u"Its tool calls are refused until you accept the change."_s);

        const auto unpinned = json::parseDoctor(fixture(u"doctor-mcp-unpinned"_s));
        QVERIFY(unpinned.ok());
        const DoctorCheck &mcp = unpinned.value().checks[0];
        QVERIFY(mcp.topic() == DoctorTopic::Mcp);
        QCOMPARE(CheckText::fix(mcp).value_or(QString{}), u"openmoat mcp accept"_s);
        QCOMPARE(CheckText::hint(unpinned.value().checks[1]).value_or(QString{}),
                 u"Not signed by a key you trust, so only its deny and ask rules apply."_s);
    }

    void doctorRepoPolicyStates() {
        const QString changed = u"p  sha256:1  changed since `openmoat trust`: tightening only"_s;
        QCOMPARE(CheckText::repoPolicyHint(changed).value_or(QString{}),
                 u"Changed since you trusted it, so only its deny and ask rules apply."_s);
        QCOMPARE(CheckText::repoPolicyHint(u"p  sha256:1  trusted (1 deny, 0 ask, 1 allow)"_s).value_or(QString{}),
                 u"Trusted with openmoat trust, so its allow rules apply too."_s);
        QCOMPARE(CheckText::repoPolicyHint(u"p  sha256:1  tightening only (1 deny)"_s).value_or(QString{}),
                 u"It only adds deny and ask rules."_s);
        QVERIFY(!CheckText::repoPolicyHint(u"something a newer moat says"_s));
        QVERIFY(CheckText::isPackFile(u"C:\\Users\\you\\.moat\\policy.d\\packs\\team.yaml was modified"_s));
        QVERIFY(!CheckText::isPackFile(u"/Users/you/.moat/policy.yaml was modified"_s));
    }

    void doctorRenamedLinesAreAboutOpenMoatAndHooks() {
        const auto doctor = json::parseDoctor(fixture(u"doctor-renamed"_s));
        QVERIFY(doctor.ok());
        const auto groups = doctor.value().groups();
        QCOMPARE(groups.size(), std::size_t{3});
        const auto topics = [](const DoctorGroup &group) {
            QStringList out;
            for (const DoctorCheck &check : group.checks) {
                out << doctorTopicLabel(check.topic());
            }
            return out;
        };
        // Warnings: the lock's old binary name and `openmoat run` first, then the hook that runs the old name.
        QCOMPARE(topics(groups[0]), (QStringList{u"OpenMoat"_s, u"OpenMoat"_s, u"Hooks"_s}));
        QCOMPARE(topics(groups[1]), (QStringList{u"OpenMoat"_s, u"Policy"_s, u"MCP servers"_s}));
        QCOMPARE(topics(groups[2]), (QStringList{u"OpenMoat"_s, u"Hooks"_s}));
        const DoctorCheck &alias = groups[1].checks[0];
        QCOMPARE(alias.title(), u"Command name"_s);
        QVERIFY(alias.subtitle().startsWith(u"`moat` is the old name of `openmoat`"_s));
        // The newer wording of lines MoatBar matches on.
        QCOMPARE(CheckText::hint(groups[1].checks[1]).value_or(QString{}),
                 u"Changed since you trusted it, so only its deny and ask rules apply."_s);
        QCOMPARE(CheckText::fix(groups[1].checks[2]).value_or(QString{}), u"openmoat mcp accept"_s);
    }

    void doctorOlderLinesKeepTheirWords() {
        const auto doctor = json::parseDoctor(fixture(u"doctor"_s));
        QVERIFY(doctor.ok());
        const auto &checks = doctor.value().checks;
        QCOMPARE(checks[0].title(), u"state directory"_s);
        QVERIFY(std::ranges::none_of(checks, [](const DoctorCheck &check) { return CheckText::fix(check).has_value(); }));
        QVERIFY(checks[6].topic() == DoctorTopic::Other);
    }

    void statusDecodesMcpChanges() {
        const auto status = json::parseStatus(fixture(u"status-mcp"_s));
        QVERIFY(status.ok());
        const QStringList &lines = status.value().mcpChanges;
        QCOMPARE(lines.size(), 4);
        QCOMPARE(McpNotices::servers(lines), (QStringList{u"gh"_s, u"docs"_s}));
        QCOMPARE(McpNotices::acceptCommands(lines, Shell::Posix),
                 (QStringList{u"openmoat mcp accept gh"_s, u"openmoat mcp accept docs"_s}));
        QVERIFY(!McpNotices::server(lines[3]));
        QVERIFY(!McpNotices::server(u"MCP server `` in /x changed"_s));
        QCOMPARE(McpNotices::acceptCommands(QStringList{u"/x cannot be read: denied"_s}, Shell::Posix),
                 QStringList{u"openmoat mcp accept"_s});
        QCOMPARE(CopyCommands::mcpAccept(u"team docs"_s, Shell::Posix), u"openmoat mcp accept 'team docs'"_s);
        QCOMPARE(CopyCommands::mcpAccept(u"team docs"_s, Shell::PowerShell), u"openmoat mcp accept 'team docs'"_s);

        for (const QString &name : {u"status"_s, u"status-notices"_s}) {
            const auto older = json::parseStatus(fixture(name));
            QVERIFY(older.ok());
            QVERIFY(older.value().mcpChanges.isEmpty());
        }
    }

    void ruleTextExplainsTheRulesMoatAdded() {
        const auto events = json::parseEvents(fixture(u"show-new-rules"_s));
        QVERIFY(events.ok());
        QStringList rules;
        for (const Event &event : events.value()) {
            rules << event.rule().value_or(QString{});
        }
        QCOMPARE(rules, (QStringList{u"package-near-miss"_s, u"push-secret"_s, u"token-egress"_s,
                                     u"mcp-server-changed"_s, u"dev-shell"_s, u"pack:team:no-deploy"_s}));
        for (const QString &rule : rules) {
            const auto why = RuleText::why(rule);
            QVERIFY2(why.has_value(), qPrintable(rule));
            QVERIFY(!why->contains(u'\n'));
        }
        QCOMPARE(RuleText::why(u"pack:team:no-deploy").value_or(QString{}),
                 u"A rule from the policy pack team, installed after its signature checked out."_s);
        QVERIFY(RuleText::why(u"repo:no-prod").has_value());
        QVERIFY(RuleText::why(RuleText::settingsDrift()).has_value());
        QVERIFY(!RuleText::why(u"my-team-rule").has_value());
    }

    void ruleTextNotesSettingsDriftBesideAnotherRule() {
        const auto events = json::parseEvents(fixture(u"show-new-rules"_s));
        QVERIFY(events.ok());
        const Event &drifted = events.value()[4];
        QCOMPARE(drifted.rule().value_or(QString{}), u"dev-shell"_s);
        QVERIFY(RuleText::driftNote(drifted.rules).value_or(QString{}).startsWith(u"A settings file OpenMoat pinned"_s));
        QVERIFY(!RuleText::driftNote(QStringList{u"settings-drift"_s}));
        QVERIFY(!RuleText::driftNote(QStringList{u"dev-shell"_s}));
        QVERIFY(!RuleText::driftNote(events.value()[0].rules));
    }

    void textInsteadOfJsonIsUnreadable() {
        const auto status = json::parseStatus(QByteArrayLiteral("Claude Code: hook + OS sandbox\n"));
        QVERIFY(!status.ok());
        QVERIFY(status.error() == (MoatError{MoatError::Kind::Unreadable, u"status"_s, {}}));
    }

    void versionTakesTheSecondWord() {
        QCOMPARE(json::parseVersion(QByteArrayLiteral("openmoat 0.9.0 (OpenMoat)\n")).value(), u"0.9.0"_s);
        QCOMPARE(json::parseVersion(QByteArrayLiteral("moat 0.5.3 (OpenMoat)\n")).value(), u"0.5.3"_s);
        QVERIFY(!json::parseVersion(QByteArrayLiteral("moat")).ok());
    }
};

QTEST_GUILESS_MAIN(TestJson)
#include "tst_json.moc"
