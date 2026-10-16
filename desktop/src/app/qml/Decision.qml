import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// One call in full: the verdict and rule, who ran it where and when, what ran,
// what the agent was told and why, then the command to check it again and docs.
ColumnLayout {
    id: decision

    property var d: ({})
    readonly property color verdictColor: Theme.tone(d.verdict || "")

    /// Text moat stored, safe to put inside styled text.
    function html(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    Layout.fillWidth: true
    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Theme.gutter
        Layout.rightMargin: Theme.gutter
        Layout.topMargin: 4
        spacing: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            Rectangle {
                width: 9
                height: 9
                radius: 4.5
                color: decision.verdictColor
            }
            Label {
                text: decision.d.title || ""
                color: decision.verdictColor
                font.pixelSize: 15
                font.weight: Font.Bold
            }
            Label {
                text: decision.d.rule || ""
                color: Theme.secondary
                font.family: Theme.mono
                font.pixelSize: 11
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                Layout.fillWidth: true
            }
        }

        GridLayout {
            columns: 2
            columnSpacing: 10
            rowSpacing: 3
            Layout.fillWidth: true
            Label { text: "Agent"; color: Theme.secondary; font.pixelSize: 12; Layout.preferredWidth: 60 }
            Label { text: decision.d.agent || ""; color: Theme.text; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            Label { text: "Time"; color: Theme.secondary; font.pixelSize: 12 }
            Label { text: decision.d.time || ""; color: Theme.text; font.pixelSize: 12 }
            Label { text: "Tool"; color: Theme.secondary; font.pixelSize: 12 }
            Label { text: decision.d.tool || ""; color: Theme.text; font.pixelSize: 12 }
            Label { visible: (decision.d.folder || "").length > 0; text: "Folder"; color: Theme.secondary; font.pixelSize: 12 }
            Label {
                visible: (decision.d.folder || "").length > 0
                text: decision.d.folder || ""
                color: Theme.text
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: code.implicitHeight + 16
            radius: 6
            color: Theme.codeBackground
            border.color: Theme.divider
            Label {
                id: code
                anchors.fill: parent
                anchors.margins: 8
                text: decision.d.display || ""
                color: Theme.text
                font.family: decision.d.monospace ? Theme.mono : Qt.application.font.family
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
        }

        Label {
            visible: (decision.d.told || "").length > 0
            text: "<b>Agent was told:</b> " + decision.html(decision.d.told || "")
            textFormat: Text.StyledText
            color: Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label {
            visible: (decision.d.why || "").length > 0
            text: "<b>Why:</b> " + decision.html(decision.d.why || "")
            textFormat: Text.StyledText
            color: Theme.text
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 4
        }
    }

    Divider {}

    CopyRow {
        visible: (decision.d.checkCommand || "").length > 0
        title: "Copy check command"
        command: decision.d.checkCommand || ""
    }
    LinkRow {
        visible: decision.d.blocked === true
        title: "Why was this blocked?"
        external: true
        onClicked: moatbar.openDocs("blocked")
    }
    LinkRow {
        visible: decision.d.blocked === true
        title: "Report a wrong block"
        external: true
        onClicked: moatbar.reportWrongBlock(decision.d.rule || "")
    }
    LinkRow {
        visible: decision.d.blocked !== true
        title: "How OpenMoat decides"
        external: true
        onClicked: moatbar.openDocs("check")
    }
}
