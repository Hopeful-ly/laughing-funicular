import QtQuick
import qs.services

// macOS toggle switch.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool v)
    implicitWidth: 38
    implicitHeight: 22
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : (Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12))
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: parent.height - 4; height: width; radius: width / 2
            y: 2
            x: sw.checked ? parent.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked); } }
}
