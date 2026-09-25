import QtQuick
import qs.services

// Rounded hover/press highlight with click handling.
Rectangle {
    id: h
    property bool hovered: ma.containsMouse
    property bool pressed: ma.pressed
    property color hoverColor: Theme.hover
    property color pressColor: Theme.pressed
    property alias mouse: ma
    property int cursor: Qt.PointingHandCursor
    property bool active: false
    property color activeColor: Theme.pressed
    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal middleClicked(var mouse)
    radius: Theme.radiusRow
    color: pressed ? pressColor : active ? activeColor : hovered ? hoverColor : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: h.cursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.RightButton) h.rightClicked(m);
            else if (m.button === Qt.MiddleButton) h.middleClicked(m);
            else h.clicked(m);
        }
    }
}
