import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// A row that opens something: a coloured dot or an agent icon, a title, an
// optional second line, a count or hint on the right and a chevron.
ItemDelegate {
    id: row

    property string title
    property string subtitle
    property string trailing
    property bool trailingStrong: false
    property color dotColor: "transparent"
    property string iconHost
    property color iconColor: Theme.secondary
    property bool chevron: true
    property bool faded: false
    property bool monospace: false

    Layout.fillWidth: true
    padding: 0
    leftPadding: Theme.gutter
    rightPadding: Theme.gutter
    topPadding: 6
    bottomPadding: 6
    opacity: faded ? 0.5 : 1
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
        spacing: 10

        Rectangle {
            visible: row.dotColor.a > 0 && row.iconHost.length === 0
            width: 8
            height: 8
            radius: 4
            color: row.dotColor
            Layout.alignment: Qt.AlignVCenter
        }
        AgentIcon {
            visible: row.iconHost.length > 0
            host: row.iconHost
            color: row.iconColor
            size: 16
            Layout.alignment: row.subtitle.length > 0 ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: row.subtitle.length > 0 ? 1 : 0
        }
        ColumnLayout {
            spacing: 1
            Layout.fillWidth: true
            Label {
                text: row.title
                color: Theme.text
                font.pixelSize: 13
                font.weight: row.subtitle.length > 0 ? Font.DemiBold : Font.Normal
                font.family: row.monospace ? Theme.mono : Qt.application.font.family
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label {
                visible: text.length > 0
                text: row.subtitle
                color: Theme.secondary
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Label {
            visible: text.length > 0
            text: row.trailing
            color: row.trailingStrong ? Theme.text : Theme.secondary
            font.pixelSize: row.trailingStrong ? 14 : 12
            font.weight: row.trailingStrong ? Font.DemiBold : Font.Normal
        }
        Label {
            visible: row.chevron
            text: "›"
            color: Theme.tertiary
            font.pixelSize: 16
        }
    }
}
