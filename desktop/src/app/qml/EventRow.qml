import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// One call in a verdict's list: what ran, the rule as a chip, the agent and
// folder, the time. Opens the call in full.
ItemDelegate {
    id: row

    property var event: ({})

    Layout.fillWidth: true
    padding: 0
    leftPadding: Theme.gutter
    rightPadding: Theme.gutter
    topPadding: 6
    bottomPadding: 6
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: (event.display || "") + ", " + (event.agent || "") + ", " + (event.time || "")

    background: Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: 5
        color: row.down ? Qt.darker(Theme.hover, 1.4) : (row.hovered || row.visualFocus ? Theme.hover : "transparent")
    }

    contentItem: RowLayout {
        spacing: 10
        AgentIcon {
            host: row.event.host || ""
            size: 14
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
        }
        ColumnLayout {
            spacing: 3
            Layout.fillWidth: true
            Label {
                text: row.event.display || ""
                color: Theme.text
                font.pixelSize: 12
                font.family: row.event.monospace ? Theme.mono : Qt.application.font.family
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Rectangle {
                    visible: (row.event.rule || "").length > 0
                    implicitWidth: rule.implicitWidth + 10
                    implicitHeight: rule.implicitHeight + 2
                    radius: height / 2
                    color: "transparent"
                    border.color: Theme.tertiary
                    Label {
                        id: rule
                        anchors.centerIn: parent
                        text: row.event.rule || ""
                        color: Theme.secondary
                        font.family: Theme.mono
                        font.pixelSize: 10
                    }
                }
                Label {
                    text: (row.event.agent || "") + ((row.event.place || "").length > 0 ? " · " + row.event.place : "")
                    color: Theme.secondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Label {
                    text: row.event.time || ""
                    color: Theme.secondary
                    font.pixelSize: 11
                }
            }
        }
        Label {
            text: "›"
            color: Theme.tertiary
            font.pixelSize: 16
        }
    }
}
