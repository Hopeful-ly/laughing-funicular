import QtQuick
import qs.services

// Tahoe Control Center module: translucent glass capsule with a bright rim.
Rectangle {
    id: t
    property bool interactive: false
    property alias hovered: ma.containsMouse
    property alias pressed: ma.pressed
    property string info: ""            // shown in the panel footer on hover
    signal clicked()
    signal rightClicked()
    radius: Math.min(height / 2, 26)
    color: interactive && ma.containsMouse ? Theme.tileHover : Theme.tile
    Behavior on color { ColorAnimation { duration: 140 } }
    border.width: 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.6)
    // top rim highlight
    Rectangle {
        anchors.top: parent.top; anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - parent.radius * 1.4; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
            GradientStop { position: 0.5; color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.9) }
            GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
    scale: interactive && ma.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: t.interactive || t.info !== ""
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: t.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => m.button === Qt.RightButton ? t.rightClicked() : t.clicked()
    }
}
