import QtQuick
import "."

// An agent's icon, drawn in `color`. Nothing for agents without one.
Image {
    property string host
    property color color: Theme.secondary
    property int size: 16

    width: size
    height: size
    sourceSize: Qt.size(size * 2, size * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: host.length > 0 && status !== Image.Error
    source: host.length > 0 ? "image://moatbar/agent/" + host + "/" + Theme.hex(color) : ""
}
