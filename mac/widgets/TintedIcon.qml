import QtQuick
import QtQuick.Effects

// Monochrome SVG recoloured to `color`.
Item {
    id: ti
    property url source
    property color color: "white"
    Image {
        id: img
        anchors.fill: parent
        source: ti.source
        sourceSize: Qt.size(ti.width * 2, ti.height * 2)
        fillMode: Image.PreserveAspectFit
        visible: false
    }
    MultiEffect {
        anchors.fill: img
        source: img
        colorization: 1
        colorizationColor: ti.color
        brightness: 1
    }
}
