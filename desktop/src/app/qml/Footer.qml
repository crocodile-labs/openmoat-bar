import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Refresh (the row spins while moat is read, then says when the data is
// from), docs, About and Quit. Always at the bottom.
ColumnLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: 6
    spacing: 0

    Divider {}

    ItemDelegate {
        id: refresh
        Layout.fillWidth: true
        padding: 0
        leftPadding: Theme.gutter
        rightPadding: Theme.gutter
        topPadding: 5
        bottomPadding: 5
        hoverEnabled: true
        focusPolicy: Qt.StrongFocus
        enabled: moatbar.refreshState !== "refreshing"
        Accessible.name: "Refresh"
        onClicked: moatbar.refresh()

        background: Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 5
            radius: 5
            color: refresh.hovered || refresh.visualFocus ? Theme.hover : "transparent"
        }
        contentItem: RowLayout {
            Label {
                text: "Refresh"
                color: Theme.text
                font.pixelSize: 13
                Layout.fillWidth: true
            }
            Label {
                text: moatbar.refreshState === "idle" ? "Ctrl+R" : moatbar.refreshText
                color: moatbar.refreshState === "done" ? Theme.green
                     : moatbar.refreshState === "failed" ? Theme.red
                     : moatbar.refreshState === "refreshing" ? Theme.secondary : Theme.tertiary
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.maximumWidth: 220
            }
            BusyIndicator {
                visible: running
                running: moatbar.refreshState === "refreshing"
                implicitWidth: 16
                implicitHeight: 16
                padding: 0
            }
        }
    }

    LinkRow {
        title: "OpenMoat docs"
        external: true
        onClicked: moatbar.openDocs("home")
    }

    Divider {}

    LinkRow {
        title: "About MoatBar"
        onClicked: moatbar.about()
    }
    LinkRow {
        title: "Quit MoatBar"
        shortcut: "Ctrl+Q"
        onClicked: moatbar.quit()
    }
}
