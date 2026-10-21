import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."

// Settings: the few things MoatBar itself decides. Nothing here changes
// OpenMoat. Data from `prefs` (Preferences); docs through `moatbar`.
ApplicationWindow {
    id: root

    title: "MoatBar Settings"
    width: 480
    height: content.implicitHeight + 40
    minimumWidth: 420
    color: Theme.window

    Shortcut { sequence: "Escape"; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.close() }

    component Heading: Label {
        color: Theme.text
        font.pixelSize: 14
        font.weight: Font.Bold
        Layout.topMargin: 8
    }
    component Note: Label {
        color: Theme.secondary
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: 32
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 20
        spacing: 6

        Heading { text: "General" }
        CheckBox {
            visible: prefs.canStartAtLogin
            text: "Start MoatBar when I log in"
            checked: prefs.startAtLogin
            onToggled: prefs.startAtLogin = checked
        }
        Note {
            visible: prefs.startAtLoginError.length > 0
            text: prefs.startAtLoginError
            color: Theme.red
        }

        Heading { text: "Notifications" }
        CheckBox {
            text: "An agent is not protected"
            checked: true
            enabled: false
        }
        Note { text: "Always on: the one thing MoatBar must never miss." }
        CheckBox {
            text: "Each blocked call"
            checked: prefs.notifyBlocks
            onToggled: prefs.notifyBlocks = checked
        }
        Note { text: "At most one per rule every 10 minutes. Shows the rule and the agent, never the command. Calls your agent already asks you about never notify." }

        Heading { text: "OpenMoat" }
        Label {
            text: "openmoat: " + (prefs.moatPath.length > 0 ? prefs.moatPath : "not found")
                  + (prefs.moatVersion.length > 0 ? " · " + prefs.moatVersion : "")
            color: Theme.text
            font.pixelSize: 12
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        Label {
            text: "MoatBar reads OpenMoat's status and audit log. It never writes to them."
            color: Theme.secondary
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            text: "<a href=\"#\">How to turn OpenMoat off ↗</a>"
            textFormat: Text.StyledText
            linkColor: Theme.accent
            font.pixelSize: 12
            onLinkActivated: moatbar.openDocs("turn-off")
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }
}
