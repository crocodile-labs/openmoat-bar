import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Who is protected: "All agents" or one agent, a protection pill in its
// colour, when the data is from and moat's version.
ColumnLayout {
    readonly property var h: moatbar.header

    Layout.fillWidth: true
    Layout.leftMargin: Theme.gutter
    Layout.rightMargin: Theme.gutter
    Layout.topMargin: 6
    Layout.bottomMargin: 6
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: h.title || ""
            color: Theme.text
            font.pixelSize: 15
            font.weight: Font.Bold
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            text: h.version || ""
            color: Theme.secondary
            font.pixelSize: 11
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            readonly property color c: Theme.tone(h.tone || "muted")
            implicitWidth: pill.implicitWidth + 14
            implicitHeight: pill.implicitHeight + 4
            radius: height / 2
            color: Qt.rgba(c.r, c.g, c.b, 0.15)
            Label {
                id: pill
                anchors.centerIn: parent
                text: h.detail || ""
                color: parent.c
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
        Label {
            text: h.updated || ""
            color: Theme.secondary
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
