import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."

// The Quick View: the macOS menu's content in a small window. Agent tabs on
// top; the overview (header, problems, Today, the four verdicts, agents,
// security checks); a click on a verdict opens its calls, a click on a call
// opens it in full. Everything comes from `moatbar` (QuickViewModel) and is
// read-only: copy a command, open a docs page, refresh.
ApplicationWindow {
    id: root

    // Windows: a flyout by the tray that closes when it loses focus.
    // Linux: a normal window the desktop places (Wayland allows nothing else).
    readonly property bool flyout: Qt.platform.os === "windows"

    title: "OpenMoat Bar"
    width: 380
    height: 720
    minimumWidth: 340
    minimumHeight: 420
    flags: flyout ? (Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint) : Qt.Window
    color: Theme.window

    // Close the flyout when focus goes elsewhere, but only after it had focus:
    // a window that never got it (offscreen, focus stealing prevention) stays.
    property bool hadFocus: false
    onActiveChanged: {
        if (active) {
            hadFocus = true;
        } else if (flyout && hadFocus && visible) {
            hide();
        }
    }
    onVisibleChanged: {
        if (!visible) {
            hadFocus = false;
            openOverview();
        }
    }

    // MARK: navigation (also used by the screenshot tool)

    function openOverview() { stack.pop(null); }
    function openList(verdict) {
        openOverview();
        stack.push(listPage, { verdict: verdict });
    }
    function openDecision(id) { stack.push(decisionPage, { eventId: id }); }
    function openChecks() {
        openOverview();
        stack.push(checksPage);
    }
    // `allowed`, `secrets` or `checks` (every openmoat doctor check).
    function openPage(page) {
        openOverview();
        if (page === "allowed") {
            stack.push(allowedPage);
        } else if (page === "secrets") {
            stack.push(secretsPage);
        } else if (page === "checks") {
            stack.push(doctorPage);
        }
    }
    function selectTab(host) {
        moatbar.selectedHost = host;
        openOverview();
    }
    function back() {
        if (stack.depth > 1) {
            stack.pop();
        } else {
            root.hide();
        }
    }

    Shortcut { sequence: "Ctrl+R"; onActivated: moatbar.refresh() }
    Shortcut { sequence: "Ctrl+A"; onActivated: moatbar.openActivity("deny") }
    Shortcut { sequence: "Ctrl+,"; onActivated: moatbar.openSettings() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: moatbar.quit() }
    Shortcut { sequence: "Escape"; onActivated: root.back() }
    Shortcut { sequence: "Backspace"; onActivated: root.back() }

    // The flyout has no frame of its own.
    Rectangle {
        anchors.fill: parent
        z: 100
        visible: root.flyout
        color: "transparent"
        border.color: Theme.divider
        border.width: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        AgentTabs {
            visible: moatbar.available
            model: moatbar.tabs
            selected: moatbar.selectedHost
            onPicked: function(host) { root.selectTab(host); }
        }

        StackView {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            initialItem: overviewPage
            // Quick, so moving in and out feels like a menu, not a phone.
            pushEnter: Transition { NumberAnimation { property: "x"; from: stack.width * 0.25; to: 0; duration: 140; easing.type: Easing.OutCubic } NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
            pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 100 } }
            popEnter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
            popExit: Transition { NumberAnimation { property: "x"; from: 0; to: stack.width * 0.25; duration: 140; easing.type: Easing.InCubic } NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 140 } }
        }

        Footer {}
    }

    // MARK: - Overview

    Component {
        id: overviewPage

        Page {
            background: null
            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    // OpenMoat missing or unreadable.
                    ColumnLayout {
                        visible: !moatbar.available
                        Layout.fillWidth: true
                        Layout.topMargin: 10
                        spacing: 0
                        Card {
                            title: moatbar.unavailable.title || ""
                            text: moatbar.unavailable.text || ""
                            note: moatbar.unavailable.note || ""
                            tint: Theme.tone(moatbar.unavailable.tone || "muted")
                        }
                        CopyRow {
                            title: moatbar.unavailable.commandTitle || ""
                            command: moatbar.unavailable.command || ""
                        }
                        LinkRow {
                            visible: (moatbar.unavailable.docs || "").length > 0
                            title: moatbar.unavailable.docsTitle || ""
                            external: true
                            onClicked: moatbar.openDocs(moatbar.unavailable.docs)
                        }
                    }

                    ColumnLayout {
                        visible: moatbar.available
                        Layout.fillWidth: true
                        spacing: 0

                        Header {}

                        Repeater {
                            model: moatbar.problems
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                Card {
                                    title: modelData.title
                                    text: modelData.text
                                    note: modelData.note
                                }
                                CopyRow {
                                    title: "Copy the fix"
                                    command: modelData.command
                                }
                            }
                        }

                        // A policy update, pinned files that changed and MCP server
                        // changes to accept: every tab.
                        Repeater {
                            model: moatbar.notices
                            delegate: ColumnLayout {
                                id: notice
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                Card {
                                    title: notice.modelData.title
                                    text: notice.modelData.text
                                    note: notice.modelData.note
                                    tint: Theme.tone(notice.modelData.tone)
                                }
                                CopyRow {
                                    title: notice.modelData.commandTitle
                                    command: notice.modelData.command
                                }
                                // One more per MCP server after the first.
                                Repeater {
                                    model: notice.modelData.moreCommands || []
                                    delegate: CopyRow {
                                        required property var modelData
                                        title: notice.modelData.commandTitle
                                        command: modelData
                                    }
                                }
                            }
                        }

                        TodayChart { today: moatbar.today }

                        Divider {}

                        Repeater {
                            model: moatbar.verdicts
                            delegate: NavRow {
                                required property var modelData
                                title: modelData.title
                                subtitle: modelData.subtitle
                                trailing: modelData.countText
                                trailingStrong: true
                                dotColor: Theme.tone(modelData.key)
                                onClicked: root.openList(modelData.key)
                            }
                        }

                        Divider {}

                        // One agent's tab: its protection and today's sessions.
                        AgentDetail {
                            visible: moatbar.agentDetail.host !== undefined
                            detail: moatbar.agentDetail
                            sessions: moatbar.sessions
                        }

                        // The All tab: every agent.
                        ColumnLayout {
                            visible: moatbar.agentDetail.host === undefined
                            Layout.fillWidth: true
                            spacing: 0
                            SectionHeader { title: "Agents" }
                            Repeater {
                                model: moatbar.agents
                                delegate: NavRow {
                                    required property var modelData
                                    title: modelData.name
                                    subtitle: modelData.detail
                                    trailing: modelData.level
                                    iconHost: modelData.host
                                    iconColor: Theme.tone(modelData.tone)
                                    onClicked: root.selectTab(modelData.host)
                                }
                            }
                            Label {
                                visible: moatbar.proxy.length > 0
                                text: "Network proxy: " + moatbar.proxy
                                color: Theme.secondary
                                font.pixelSize: 12
                                Layout.leftMargin: Theme.gutter
                                Layout.topMargin: 4
                                Layout.bottomMargin: 2
                            }
                        }

                        Divider {}

                        NavRow {
                            title: "Security checks"
                            trailing: moatbar.checksHint
                            dotColor: moatbar.checksHint === "all fine" ? Theme.green : Theme.orange
                            onClicked: root.openChecks()
                        }
                        NavRow {
                            title: "What you allowed"
                            subtitle: "Rules, session grants and trusted repositories"
                            onClicked: root.openPage("allowed")
                        }
                        NavRow {
                            title: "Secrets"
                            subtitle: "Tokens OpenMoat adds to requests for the agent"
                            onClicked: root.openPage("secrets")
                        }
                        NavRow {
                            title: "Checks"
                            subtitle: "Every openmoat doctor check"
                            onClicked: root.openPage("checks")
                        }
                    }
                }
            }
        }
    }

    // MARK: - A verdict's calls

    Component {
        id: listPage

        Page {
            id: page
            property string verdict
            readonly property var items: { moatbar.revision; return moatbar.events(verdict); }
            readonly property int more: { moatbar.revision; return moatbar.moreEvents(verdict); }
            readonly property var info: {
                var all = moatbar.verdicts;
                for (var i = 0; i < all.length; ++i) {
                    if (all[i].key === verdict) {
                        return all[i];
                    }
                }
                return { title: "", subtitle: "", countText: "" };
            }
            background: null

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: page.info.title + " today"
                        trailing: page.info.countText
                        onBack: root.back()
                    }
                    Label {
                        text: page.info.subtitle
                        color: Theme.secondary
                        font.pixelSize: 12
                        Layout.leftMargin: Theme.gutter
                        Layout.bottomMargin: 6
                    }
                    Label {
                        visible: page.items.length === 0
                        text: "Nothing " + page.info.title.toLowerCase() + " today"
                        color: Theme.secondary
                        font.pixelSize: 13
                        Layout.leftMargin: Theme.gutter
                        Layout.topMargin: 8
                    }
                    Repeater {
                        model: page.items
                        delegate: EventRow {
                            required property var modelData
                            event: modelData
                            onClicked: root.openDecision(modelData.id)
                        }
                    }
                    Divider {}
                    LinkRow {
                        title: "Show all in Activity…" + (page.more > 0 ? " (" + page.more + " more)" : "")
                        onClicked: moatbar.openActivity(page.verdict)
                    }
                }
            }
        }
    }

    // MARK: - One call

    Component {
        id: decisionPage

        Page {
            id: page
            property string eventId
            readonly property var d: { moatbar.revision; return moatbar.decision(eventId); }
            background: null

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: page.d.id !== undefined ? "Call details" : "Gone"
                        onBack: root.back()
                    }
                    Label {
                        visible: page.d.id === undefined
                        text: "OpenMoat no longer lists this call."
                        color: Theme.secondary
                        Layout.leftMargin: Theme.gutter
                    }
                    Decision {
                        visible: page.d.id !== undefined
                        d: page.d
                    }
                    LinkRow {
                        visible: page.d.id !== undefined
                        title: "Show in Activity…"
                        onClicked: moatbar.openActivity(page.d.verdict)
                    }
                }
            }
        }
    }

    // MARK: - Security checks

    Component {
        id: checksPage

        Page {
            id: page
            background: null

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: "Security checks"
                        trailing: moatbar.checksHint
                        onBack: root.back()
                    }
                    Repeater {
                        model: moatbar.checks
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 0
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Theme.gutter
                                Layout.rightMargin: Theme.gutter
                                spacing: 10
                                Label {
                                    text: modelData.tone === "ok" ? "✓" : (modelData.tone === "info" ? "i" : "!")
                                    color: Theme.tone(modelData.tone)
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.preferredWidth: 14
                                    Layout.alignment: Qt.AlignTop
                                }
                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Label {
                                        text: modelData.title
                                        color: Theme.text
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        visible: text.length > 0
                                        text: modelData.detail
                                        color: Theme.secondary
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            CopyRow {
                                visible: modelData.fix.length > 0
                                title: "Copy the fix"
                                command: modelData.fix
                            }
                        }
                    }
                    Divider {}
                    CopyRow {
                        title: "Copy for every check"
                        command: moatbar.doctorCommand
                    }
                    LinkRow {
                        title: "Every check…"
                        onClicked: root.openPage("checks")
                    }
                }
            }
        }
    }

    // MARK: - What you allowed

    Component {
        id: allowedPage

        Page {
            id: page
            readonly property var a: details.allowed
            background: null
            Component.onCompleted: moatbar.openDetails("allowed")

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: "What you allowed"
                        trailing: details.loading ? "Reading…" : ""
                        onBack: root.back()
                    }
                    Label {
                        visible: page.a.state !== "loaded"
                        text: page.a.note || ""
                        color: page.a.state === "failed" ? Theme.orange : Theme.secondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.gutter
                        Layout.rightMargin: Theme.gutter
                        Layout.topMargin: 6
                    }

                    ColumnLayout {
                        visible: page.a.state === "loaded"
                        Layout.fillWidth: true
                        spacing: 0

                        SectionHeader {
                            title: "Permanent rules"
                            trailing: String((page.a.rules || []).length)
                        }
                        Label {
                            visible: (page.a.rules || []).length === 0
                            text: "None. openmoat allow --always, --site and --dir add them."
                            color: Theme.secondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.gutter
                            Layout.rightMargin: Theme.gutter
                        }
                        Repeater {
                            model: page.a.rules || []
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                DetailRow {
                                    title: modelData.title
                                    detail: modelData.detail
                                    monospace: true
                                }
                                CopyRow {
                                    title: "Copy the remove command"
                                    command: modelData.command
                                }
                            }
                        }

                        SectionHeader {
                            title: "Session grants"
                            trailing: String((page.a.grants || []).length)
                        }
                        Label {
                            visible: (page.a.grants || []).length === 0
                            text: "None. openmoat allow --last allows one call again for the rest of its session."
                            color: Theme.secondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.gutter
                            Layout.rightMargin: Theme.gutter
                        }
                        Repeater {
                            model: page.a.grants || []
                            delegate: DetailRow {
                                required property var modelData
                                title: modelData.title
                                detail: modelData.detail
                                monospace: true
                            }
                        }

                        SectionHeader {
                            title: "Trusted repositories"
                            trailing: String((page.a.repos || []).length)
                        }
                        Label {
                            visible: (page.a.repos || []).length === 0
                            text: "None. openmoat trust lets a repository's own policy allow calls."
                            color: Theme.secondary
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.gutter
                            Layout.rightMargin: Theme.gutter
                        }
                        Repeater {
                            model: page.a.repos || []
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                DetailRow {
                                    title: modelData.title
                                    detail: modelData.detail
                                    monospace: true
                                }
                                CopyRow {
                                    title: "Copy the revoke command"
                                    command: modelData.command
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Secrets

    Component {
        id: secretsPage

        Page {
            id: page
            readonly property var s: details.secrets
            background: null
            Component.onCompleted: moatbar.openDetails("secrets")

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: "Secrets"
                        trailing: details.loading ? "Reading…" : (page.s.hint || "")
                        onBack: root.back()
                    }
                    Label {
                        visible: page.s.state !== "loaded"
                        text: page.s.note || ""
                        color: page.s.state === "failed" ? Theme.orange : Theme.secondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.gutter
                        Layout.rightMargin: Theme.gutter
                        Layout.topMargin: 6
                    }
                    Label {
                        visible: page.s.state === "loaded" && (page.s.items || []).length === 0
                        text: "None. openmoat secret add keeps a token away from the agent and adds it to requests."
                        color: Theme.secondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.gutter
                        Layout.rightMargin: Theme.gutter
                        Layout.topMargin: 6
                    }
                    Repeater {
                        model: page.s.state === "loaded" ? (page.s.items || []) : []
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.bottomMargin: 4
                            spacing: 0
                            DetailRow {
                                title: modelData.id + "  ·  " + modelData.host
                                detail: modelData.line + "\n" + modelData.hint
                                dotColor: Theme.tone(modelData.tone)
                            }
                            CopyRow {
                                visible: modelData.command.length > 0
                                title: "Copy the check command"
                                command: modelData.command
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Every openmoat doctor check

    Component {
        id: doctorPage

        Page {
            id: page
            readonly property var c: details.checks
            background: null
            Component.onCompleted: moatbar.openDetails("checks")

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0

                    PageHeader {
                        title: "Checks"
                        trailing: details.loading ? "Reading…" : (page.c.summary || "")
                        onBack: root.back()
                    }
                    Label {
                        visible: details.updateNote.length > 0
                        text: details.updateNote
                        color: Theme.secondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.gutter
                        Layout.rightMargin: Theme.gutter
                        Layout.topMargin: 6
                    }
                    Label {
                        visible: page.c.state !== "loaded"
                        text: page.c.note || ""
                        color: page.c.state === "failed" ? Theme.orange : Theme.secondary
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.gutter
                        Layout.rightMargin: Theme.gutter
                        Layout.topMargin: 6
                    }
                    Repeater {
                        model: page.c.state === "loaded" ? (page.c.groups || []) : []
                        delegate: ColumnLayout {
                            id: group
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0
                            SectionHeader {
                                title: group.modelData.title
                                trailing: String(group.modelData.count)
                            }
                            Repeater {
                                model: group.modelData.items
                                delegate: ColumnLayout {
                                    id: check
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 0
                                    DetailRow {
                                        title: check.modelData.title
                                        caption: check.modelData.topic || ""
                                        detail: check.modelData.subtitle
                                        hint: check.modelData.hint || ""
                                        dotColor: Theme.tone(group.modelData.tone)
                                    }
                                    CopyRow {
                                        visible: (check.modelData.command || "").length > 0
                                        title: "Copy the command"
                                        command: check.modelData.command || ""
                                    }
                                }
                            }
                        }
                    }
                    Divider { visible: page.c.state === "loaded" }
                    CopyRow {
                        title: "Copy for every check"
                        command: moatbar.doctorCommand
                    }
                }
            }
        }
    }
}
