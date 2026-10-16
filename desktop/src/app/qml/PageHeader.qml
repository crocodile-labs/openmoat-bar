import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// The top of a page opened from the overview: Back, the title and a count.
RowLayout {
    property string title
    property string trailing
    signal back()

    Layout.fillWidth: true
    Layout.leftMargin: 6
    Layout.rightMargin: Theme.gutter
    Layout.topMargin: 2
    spacing: 4

    ToolButton {
        text: "‹ Back"
        font.pixelSize: 12
        onClicked: parent.back()
        Accessible.name: "Back"
    }
    Label {
        text: parent.title
        color: Theme.text
        font.pixelSize: 14
        font.weight: Font.Bold
        elide: Text.ElideRight
        Layout.fillWidth: true
    }
    Label {
        visible: text.length > 0
        text: parent.trailing
        color: Theme.secondary
        font.pixelSize: 12
    }
}
