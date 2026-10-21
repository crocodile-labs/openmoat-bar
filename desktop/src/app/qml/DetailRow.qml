import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// One item on a detail page: an optional dot, a title with an optional caption
// beside it, and lines under it. Shown, not clickable; a CopyRow below it
// carries any command.
RowLayout {
    id: row

    property string title
    property string detail
    property string caption
    property string hint
    property bool monospace: false
    property color dotColor: "transparent"

    Layout.fillWidth: true
    Layout.leftMargin: Theme.gutter
    Layout.rightMargin: Theme.gutter
    Layout.topMargin: 4
    spacing: 10

    Rectangle {
        visible: row.dotColor.a > 0
        width: 8
        height: 8
        radius: 4
        color: row.dotColor
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 5
    }
    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true
        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Label {
                text: row.title
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                font.family: row.monospace ? Theme.mono : Qt.application.font.family
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            Label {
                visible: text.length > 0
                text: row.caption
                color: Theme.secondary
                font.pixelSize: 10
                Layout.alignment: Qt.AlignTop
            }
        }
        Label {
            visible: text.length > 0
            text: row.detail
            color: Theme.secondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: row.hint
            color: Theme.secondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
