import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// A plain action row: a docs link (with ↗), About, Quit.
ItemDelegate {
    id: row

    property string title
    property bool external: false
    property string shortcut

    Layout.fillWidth: true
    padding: 0
    leftPadding: Theme.gutter
    rightPadding: Theme.gutter
    topPadding: 5
    bottomPadding: 5
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    background: Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: 5
        color: row.down ? Qt.darker(Theme.hover, 1.4) : (row.hovered || row.visualFocus ? Theme.hover : "transparent")
    }

    contentItem: RowLayout {
        Label {
            text: row.title + (row.external ? " ↗" : "")
            color: Theme.text
            font.pixelSize: 13
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: row.shortcut
            color: Theme.tertiary
            font.pixelSize: 12
        }
    }
}
