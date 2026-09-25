import QtQuick
import qs.services

// Round Control Center toggle (Wi-Fi, Bluetooth, ...).
Rectangle {
    id: c
    property bool on: false
    property string icon: ""
    property int diameter: 32
    signal clicked()
    width: diameter; height: diameter; radius: diameter / 2
    color: on ? Theme.accent : (ma.containsMouse ? Theme.tileHover : (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)))
    Behavior on color { ColorAnimation { duration: 140 } }
    Sym { anchors.centerIn: parent; name: c.icon; size: c.diameter * 0.55; filled: true; color: c.on ? Theme.accentText : Theme.text }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.clicked() }
    scale: ma.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
}
