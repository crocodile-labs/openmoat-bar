import QtQuick
import "."

// An agent's icon, drawn in `color`, in a `size` square (an Image's own
// implicit size is its pixel size, which layouts would use). Nothing for
// agents without one.
Item {
    id: icon

    property string host
    property color color: Theme.secondary
    property int size: 16

    implicitWidth: size
    implicitHeight: size
    visible: host.length > 0 && image.status !== Image.Error

    Image {
        id: image
        anchors.fill: parent
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        source: icon.host.length > 0 ? "image://moatbar/agent/" + icon.host + "/" + Theme.hex(icon.color) : ""
    }
}
