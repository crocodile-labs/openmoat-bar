import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."

// The first-launch window: what OpenMoat Bar is, in three lines, then the Quick
// View. Shown once. `prefs` for start at login; `welcome` (the window's
// controller) for the two buttons.
ApplicationWindow {
    id: root

    title: "Welcome to OpenMoat Bar"
    width: 480
    height: content.implicitHeight + 56
    minimumWidth: 420
    color: Theme.window

    component Point: RowLayout {
        property string symbol
        property color tint
        property string heading
        property string body
        spacing: 12
        Layout.fillWidth: true
        Rectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 26
            implicitHeight: 26
            radius: 13
            color: Qt.rgba(parent.tint.r, parent.tint.g, parent.tint.b, 0.15)
            Label {
                anchors.centerIn: parent
                text: parent.parent.symbol
                color: parent.parent.tint
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }
        ColumnLayout {
            spacing: 2
            Layout.fillWidth: true
            Label {
                text: parent.parent.heading
                color: Theme.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Label {
                text: parent.parent.body
                color: Theme.secondary
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 28
        spacing: 10

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "image://moatbar/logo-large"
            sourceSize: Qt.size(360, 180)
            Layout.preferredWidth: 180
            Layout.preferredHeight: 90
            fillMode: Image.PreserveAspectFit
            smooth: true
            Accessible.name: "OpenMoat"
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Welcome to OpenMoat Bar"
            color: Theme.text
            font.pixelSize: 22
            font.weight: Font.Bold
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "See what OpenMoat does for your coding agents."
            color: Theme.secondary
            font.pixelSize: 13
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 8
            spacing: 14
            Point {
                symbol: "✕"
                tint: Theme.red
                heading: "What was blocked, and why"
                body: "Every stop with its rule and the plain reason your agent was given."
            }
            Point {
                symbol: "✓"
                tint: Theme.green
                heading: "Whether each agent is protected"
                body: "Checked every minute. You hear about it if one drops."
            }
            Point {
                symbol: "i"
                tint: Theme.blue
                heading: "Read-only"
                body: "OpenMoat Bar never allows anything or changes a rule. Fixes are commands you copy."
            }
        }

        CheckBox {
            visible: prefs.canStartAtLogin
            text: "Start OpenMoat Bar when I log in"
            checked: prefs.startAtLogin
            onToggled: prefs.startAtLogin = checked
        }

        Label {
            text: "OpenMoat Bar lives in the tray. Click its croc to see what OpenMoat did; right-click for the menu."
            color: Theme.secondary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Item { Layout.fillWidth: true }
            Button {
                text: "Quit"
                onClicked: welcome.quit()
            }
            Button {
                text: "Open OpenMoat Bar"
                highlighted: true
                onClicked: welcome.open()
                Component.onCompleted: forceActiveFocus()
                Keys.onReturnPressed: welcome.open()
            }
        }
    }
}
