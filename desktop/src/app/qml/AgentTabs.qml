import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// All + one tab per agent moat reports, with each agent's icon and a line
// under it in its protection colour. Agents that aren't installed are faded.
// Wraps into rows of five, like the macOS tab bar.
Flow {
    id: tabs

    property var model: []
    property string selected
    signal picked(string host)

    readonly property int columns: Math.min(5, Math.max(1, model.length))
    readonly property real tabWidth: (width - spacing * (columns - 1)) / columns

    Layout.fillWidth: true
    Layout.leftMargin: 10
    Layout.rightMargin: 10
    Layout.topMargin: 10
    Layout.bottomMargin: 4
    spacing: 4

    Repeater {
        model: tabs.model
        delegate: AbstractButton {
            id: tab
            required property var modelData
            readonly property bool current: modelData.host === tabs.selected

            width: tabs.tabWidth
            height: 46
            hoverEnabled: true
            focusPolicy: Qt.StrongFocus
            opacity: modelData.installed ? 1 : 0.45
            Accessible.name: modelData.name + (current ? ", selected" : "")
            onClicked: tabs.picked(modelData.host)

            background: Rectangle {
                radius: 7
                color: tab.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                   : (tab.hovered || tab.visualFocus ? Theme.hover : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            contentItem: ColumnLayout {
                spacing: 3
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 18
                    implicitHeight: 18
                    AgentIcon {
                        anchors.centerIn: parent
                        host: tab.modelData.host
                        size: 18
                        color: tab.current ? Theme.text : Theme.secondary
                    }
                    Image {
                        // "All" has no agent icon: the croc stands for every agent.
                        anchors.centerIn: parent
                        visible: tab.modelData.host.length === 0
                        source: visible ? "image://moatbar/logo" : ""
                        sourceSize: Qt.size(36, 36)
                        width: 18
                        height: 18
                        smooth: true
                    }
                }
                Label {
                    text: tab.modelData.name
                    color: tab.current ? Theme.text : Theme.secondary
                    font.pixelSize: 11
                    font.weight: tab.current ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 18
                    implicitHeight: 2
                    radius: 1
                    color: tab.modelData.tone.length > 0 ? Theme.tone(tab.modelData.tone) : "transparent"
                }
            }
        }
    }
}
