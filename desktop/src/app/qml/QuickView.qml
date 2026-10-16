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

    title: "MoatBar"
    width: 380
    height: 640
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
                    Label {
                        visible: page.more > 0
                        text: page.more + " more. The Activity window lists them all."
                        color: Theme.secondary
                        font.pixelSize: 12
                        Layout.leftMargin: Theme.gutter
                        Layout.topMargin: 6
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
                        title: page.d.title || "Gone"
                        onBack: root.back()
                    }
                    Label {
                        visible: page.d.id === undefined
                        text: "moat no longer lists this call."
                        color: Theme.secondary
                        Layout.leftMargin: Theme.gutter
                    }
                    Decision {
                        visible: page.d.id !== undefined
                        d: page.d
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
                }
            }
        }
    }
}
