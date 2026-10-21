import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// One agent's tab: its protection, what moat doesn't cover for it, its last
// call and today's sessions, and the set-up command when it needs one.
ColumnLayout {
    id: agent

    property var detail: ({})
    property var sessions: []
    readonly property color levelColor: Theme.tone(detail.tone || "muted")

    Layout.fillWidth: true
    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.gutter
        Layout.rightMargin: Theme.gutter
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 4

        RowLayout {
            spacing: 8
            AgentIcon {
                host: agent.detail.host || ""
                color: agent.levelColor
                size: 18
            }
            Label {
                text: agent.detail.name || ""
                color: Theme.text
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Label {
                text: agent.detail.level || ""
                color: agent.levelColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        Label {
            visible: agent.detail.installed === false
            text: (agent.detail.name || "")
                  + " isn't installed on this computer. Once it is, run openmoat to protect it."
            color: Theme.secondary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            visible: (agent.detail.reason || "").length > 0
            text: agent.detail.reason || ""
            color: Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            visible: (agent.detail.lastCall || "").length > 0
            text: "Last call " + (agent.detail.lastCall || "")
            color: Theme.secondary
            font.pixelSize: 12
        }
        Label {
            visible: (agent.detail.gaps || "").length > 0
            text: "Not covered: " + (agent.detail.gaps || "")
            color: Theme.secondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    CopyRow {
        visible: (agent.detail.setUpCommand || "").length > 0
        title: "Copy the set-up command"
        command: agent.detail.setUpCommand || ""
    }
    LinkRow {
        title: "Known limits"
        external: true
        onClicked: moatbar.openDocs("limits")
    }

    SectionHeader {
        visible: agent.detail.installed !== false
        title: "Sessions today"
        trailing: agent.sessions.length > 0 ? String(agent.sessions.length) : ""
    }
    Label {
        visible: agent.detail.installed !== false && agent.sessions.length === 0
        text: (agent.detail.name || "") + " hasn't run today"
        color: Theme.secondary
        font.pixelSize: 12
        Layout.leftMargin: Theme.gutter
    }
    Repeater {
        model: agent.sessions
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Layout.leftMargin: Theme.gutter
            Layout.rightMargin: Theme.gutter
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: 0
            Label {
                text: modelData.title
                color: Theme.text
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
            Label {
                text: modelData.detail
                color: Theme.secondary
                font.pixelSize: 11
            }
        }
    }
}
