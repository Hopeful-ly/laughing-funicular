import QtQuick
import qs.services

// Control Center module background.
Rectangle {
    id: t
    property bool interactive: false
    property alias hovered: ma.containsMouse
    signal clicked()
    radius: Theme.radiusTile
    color: interactive && ma.containsMouse ? Theme.tileHover : Theme.tile
    border.width: 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.5)
    Behavior on color { ColorAnimation { duration: 120 } }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: t.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: t.clicked()
    }
}
