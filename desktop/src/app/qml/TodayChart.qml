import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

// Today's calls per hour, each bar stacked by verdict with blocks on top in
// red, like the macOS menu's Today bar. Hours still to come are faded.
ColumnLayout {
    id: chart

    property var today: ({})
    readonly property var hours: today.hours || []
    readonly property int peak: Math.max(1, today.peak || 1)

    Layout.fillWidth: true
    Layout.leftMargin: Theme.gutter
    Layout.rightMargin: Theme.gutter
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    spacing: 4
    Accessible.role: Accessible.Chart
    Accessible.name: "Today: " + (today.total || 0) + " calls"

    RowLayout {
        Layout.fillWidth: true
        Label {
            text: "Today"
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        Label {
            text: (chart.today.total || 0) + " calls · " + (chart.today.sessions || 0) + " sessions"
            color: Theme.secondary
            font.pixelSize: 12
        }
    }

    Row {
        id: bars
        Layout.fillWidth: true
        Layout.preferredHeight: 30
        spacing: 2
        readonly property real barWidth: Math.max(2, (width - spacing * 23) / 24)

        Repeater {
            model: chart.hours
            delegate: Rectangle {
                id: bar
                required property var modelData
                required property int index
                width: bars.barWidth
                height: bars.height
                radius: 1
                color: Theme.track
                opacity: index > (chart.today.currentHour || 0) ? 0.35 : 1

                Column {
                    anchors.bottom: parent.bottom
                    width: bar.width
                    Repeater {
                        // Top to bottom: blocked, asked, left to the agent, allowed.
                        model: ["deny", "ask", "deferred", "allow"]
                        delegate: Rectangle {
                            required property string modelData
                            readonly property int n: bar.modelData[modelData] || 0
                            width: bar.width
                            height: n > 0 ? Math.max(modelData === "deny" ? 3 : 1, bars.height * n / chart.peak) : 0
                            color: Theme.tone(modelData)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["00", "06", "12", "18", "24"]
            delegate: Label {
                required property string modelData
                required property int index
                text: modelData
                color: Theme.secondary
                font.pixelSize: 9
                horizontalAlignment: index === 0 ? Text.AlignLeft : (index === 4 ? Text.AlignRight : Text.AlignHCenter)
                Layout.fillWidth: true
            }
        }
    }
}
