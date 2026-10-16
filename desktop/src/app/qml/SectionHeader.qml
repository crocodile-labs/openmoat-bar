import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// A small all-caps heading, with an optional count or note on the right.
RowLayout {
    property string title
    property string trailing

    Layout.fillWidth: true
    Layout.leftMargin: Theme.gutter
    Layout.rightMargin: Theme.gutter
    Layout.topMargin: 6
    Layout.bottomMargin: 2

    Label {
        text: parent.title.toUpperCase()
        color: Theme.secondary
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        Layout.fillWidth: true
    }
    Label {
        text: parent.trailing
        color: Theme.secondary
        font.pixelSize: 11
        visible: text.length > 0
    }
}
