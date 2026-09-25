import QtQuick
import qs.services

// Round Control Center button. "on" = white disc with accent glyph (Tahoe).
Rectangle {
    id: c
    property bool on: false
    property string icon: ""
    property int diameter: 64
    property real iconScale: 0.42
    property string info: ""
    readonly property alias hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    width: diameter; height: diameter; radius: diameter / 2
    color: on ? (ma.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.94)) : ma.containsMouse ? Theme.tileHover : Theme.tile
    Behavior on color { ColorAnimation { duration: 160 } }
    border.width: on ? 0 : 1
    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.6)
    Sym {
        anchors.centerIn: parent
        name: c.icon
        size: c.diameter * c.iconScale
        filled: true
        color: c.on ? Theme.accent : Theme.text
        Behavior on color { ColorAnimation { duration: 160 } }
    }
    scale: ma.pressed ? 0.93 : 1
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => m.button === Qt.RightButton ? c.rightClicked() : c.clicked()
    }
}
