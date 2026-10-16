import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// A tinted box for something that needs the person: an agent that isn't
// protected, OpenMoat missing or unreadable.
Rectangle {
    id: card

    property string title
    property string text
    property string note
    property color tint: Theme.red

    Layout.fillWidth: true
    Layout.leftMargin: Theme.gutter - 4
    Layout.rightMargin: Theme.gutter - 4
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    implicitHeight: column.implicitHeight + 20
    radius: 9
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.12)

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        RowLayout {
            spacing: 8
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: card.tint
            }
            Label {
                text: card.title
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.Bold
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        Label {
            text: card.text
            color: Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            visible: text.length > 0
            text: card.note
            color: Theme.secondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
