import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "."

// The long view: every call in a window (today, 7 days, 30 days), filtered by
// agent, verdict and rule, with one call in full on the right. Data comes from
// `activity` (ActivityModel); copying and docs go through `moatbar`.
ApplicationWindow {
    id: root

    title: "MoatBar Activity"
    width: 1040
    height: 620
    minimumWidth: 820
    minimumHeight: 460
    color: Theme.window

    Shortcut { sequence: "Ctrl+R"; onActivated: activity.load() }
    Shortcut { sequence: "Ctrl+W"; onActivated: root.close() }
    Shortcut { sequence: "Escape"; onActivated: root.close() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // MARK: toolbar

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            spacing: 10

            Row {
                spacing: 0
                Repeater {
                    model: activity.windowTitles
                    delegate: Button {
                        required property string modelData
                        required property int index
                        text: modelData
                        checkable: true
                        checked: activity.windowIndex === index
                        onClicked: activity.windowIndex = index
                        Accessible.name: "Show " + modelData
                    }
                }
            }

            ComboBox {
                id: agentPicker
                Layout.preferredWidth: 180
                textRole: "name"
                valueRole: "host"
                model: [{ host: "", name: "All agents" }].concat(activity.agents)
                currentIndex: Math.max(0, indexOfValue(activity.host))
                onActivated: activity.host = currentValue
                Accessible.name: "Agent"
            }

            BusyIndicator {
                running: activity.loading
                visible: running
                implicitWidth: 20
                implicitHeight: 20
                padding: 0
            }
            Label {
                visible: text.length > 0
                text: activity.error
                color: Theme.red
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.maximumWidth: 320
            }
            Item { Layout.fillWidth: true }
            Label {
                visible: text.length > 0
                text: activity.exportNote
                color: Theme.secondary
                font.pixelSize: 12
                elide: Text.ElideMiddle
                Layout.maximumWidth: 320
            }
            Button {
                text: "Refresh"
                onClicked: activity.load()
            }
            Button {
                text: "Export…"
                enabled: activity.rows.length > 0
                onClicked: activity.exportRows()
                ToolTip.visible: hovered
                ToolTip.delay: 600
                ToolTip.text: "Save the calls shown, one JSON object per line, as openmoat printed them"
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.divider }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // MARK: sidebar

            ScrollView {
                Layout.preferredWidth: 230
                Layout.fillHeight: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 2

                    Item { implicitHeight: 6 }
                    Repeater {
                        model: activity.verdictCounts
                        delegate: ItemDelegate {
                            id: verdictButton
                            required property var modelData
                            readonly property bool on: activity.verdict === modelData.key
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            padding: 0
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 5
                            bottomPadding: 5
                            onClicked: activity.verdict = modelData.key
                            background: Rectangle {
                                radius: 6
                                color: verdictButton.on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                                                        : (verdictButton.hovered ? Theme.hover : "transparent")
                            }
                            contentItem: RowLayout {
                                spacing: 8
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.tone(verdictButton.modelData.key)
                                }
                                Label {
                                    text: verdictButton.modelData.title
                                    color: Theme.text
                                    font.pixelSize: 13
                                    font.weight: verdictButton.on ? Font.DemiBold : Font.Normal
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: verdictButton.modelData.countText
                                    color: Theme.secondary
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.margins: 8; implicitHeight: 1; color: Theme.divider }
                    SectionHeader { title: "Rules that blocked or asked" }
                    Label {
                        visible: activity.topRules.length === 0
                        text: "None in this window"
                        color: Theme.secondary
                        font.pixelSize: 12
                        Layout.leftMargin: Theme.gutter
                    }
                    Repeater {
                        model: activity.topRules
                        delegate: ItemDelegate {
                            id: ruleButton
                            required property var modelData
                            readonly property bool on: activity.rule === modelData.rule
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            padding: 0
                            leftPadding: 8
                            rightPadding: 8
                            topPadding: 3
                            bottomPadding: 3
                            onClicked: activity.toggleRule(modelData.rule)
                            Accessible.name: "Only " + modelData.rule
                            background: Rectangle {
                                radius: 5
                                color: ruleButton.hovered ? Theme.hover : "transparent"
                            }
                            contentItem: RowLayout {
                                Label {
                                    text: ruleButton.modelData.rule
                                    color: ruleButton.on ? Theme.accent : Theme.text
                                    font.family: Theme.mono
                                    font.pixelSize: 12
                                    font.weight: ruleButton.on ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Label {
                                    text: ruleButton.modelData.countText
                                    color: Theme.secondary
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.margins: 8; implicitHeight: 1; color: Theme.divider }
                    Label {
                        text: activity.sessionsText
                        color: Theme.secondary
                        font.pixelSize: 12
                        Layout.leftMargin: Theme.gutter
                        Layout.bottomMargin: 8
                    }
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.divider }

            // MARK: list

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 320
                spacing: 0

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: activity.rows
                    currentIndex: -1
                    keyNavigationEnabled: true
                    focus: true
                    ScrollBar.vertical: ScrollBar {}
                    Keys.onUpPressed: moveSelection(-1)
                    Keys.onDownPressed: moveSelection(1)

                    function moveSelection(step) {
                        var rows = activity.rows;
                        for (var i = 0; i < rows.length; ++i) {
                            if (rows[i].id === activity.selectedId) {
                                var next = Math.max(0, Math.min(rows.length - 1, i + step));
                                activity.selectedId = rows[next].id;
                                list.positionViewAtIndex(next, ListView.Contain);
                                return;
                            }
                        }
                    }

                    delegate: ItemDelegate {
                        id: row
                        required property var modelData
                        readonly property bool on: activity.selectedId === modelData.id
                        width: ListView.view.width
                        padding: 0
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 5
                        bottomPadding: 5
                        onClicked: activity.selectedId = modelData.id
                        background: Rectangle {
                            color: row.on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                          : (row.hovered ? Theme.hover : "transparent")
                        }
                        contentItem: ColumnLayout {
                            spacing: 2
                            Label {
                                text: row.modelData.display
                                color: Theme.text
                                font.pixelSize: 12
                                font.family: row.modelData.monospace ? Theme.mono : Qt.application.font.family
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 7
                                    height: 7
                                    radius: 3.5
                                    color: Theme.tone(row.modelData.verdict)
                                }
                                Label {
                                    text: [row.modelData.verdictTitle, row.modelData.rule, row.modelData.agent, row.modelData.time]
                                          .filter(function(part) { return part.length > 0; }).join(" · ")
                                    color: Theme.secondary
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: list.count === 0 && !activity.loading
                        text: "Nothing here for this window"
                        color: Theme.secondary
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.divider }
                Label {
                    text: activity.rowsNote
                    color: Theme.secondary
                    font.pixelSize: 11
                    Layout.margins: 6
                    Layout.leftMargin: 12
                }
            }

            Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.divider }

            // MARK: one call

            ScrollView {
                Layout.preferredWidth: 380
                Layout.fillHeight: true
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 0
                    Item { implicitHeight: 10 }
                    Decision {
                        visible: activity.selected.id !== undefined
                        d: activity.selected
                    }
                    Label {
                        visible: activity.selected.id === undefined
                        text: "Pick a call to see it in full"
                        color: Theme.secondary
                        Layout.leftMargin: Theme.gutter
                        Layout.topMargin: 10
                    }
                }
            }
        }
    }
}
