import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Copies a command to paste into a terminal and says "Copied ✓" for a moment.
// MoatBar never runs the command itself.
ItemDelegate {
    id: row

    property string title
    property string command
    property bool copied: false

    Layout.fillWidth: true
    padding: 0
    leftPadding: Theme.gutter
    rightPadding: Theme.gutter
    topPadding: 5
    bottomPadding: 5
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    ToolTip.visible: hovered && !copied
    ToolTip.delay: 600
    ToolTip.text: "Copies " + command + " to paste into a terminal"
    Accessible.name: title + ": " + command

    onClicked: {
        moatbar.copy(command);
        copied = true;
        settle.restart();
    }
    Timer {
        id: settle
        interval: 1500
        onTriggered: row.copied = false
    }

    background: Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: 5
        color: row.hovered || row.visualFocus ? Theme.hover : "transparent"
    }

    contentItem: ColumnLayout {
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: row.title
                color: Theme.text
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Label {
                text: row.copied ? "Copied ✓" : "Copy"
                color: row.copied ? Theme.green : Theme.accent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
        Label {
            text: row.command
            color: Theme.secondary
            font.family: Theme.mono
            font.pixelSize: 11
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
    }
}
