import QtQuick
import qs.services

// Control Center slider: thick capsule, white fill, symbol inside.
Item {
    id: s
    property real value: 0.5
    property string icon: "light_mode"
    property bool dimIcon: false
    signal moved(real v)
    signal iconClicked()
    implicitHeight: 28

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(parent.height, parent.width * s.value)
            radius: height / 2
            color: Theme.dark ? "#f2f2f7" : "#ffffff"
            Behavior on width { enabled: !ma.pressed; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
    }
    Sym {
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        name: s.icon
        size: 17
        filled: true
        color: "#3a3a3c"
        opacity: s.dimIcon ? 0.5 : 0.9
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function upd(x) { const v = Math.max(0, Math.min(1, x / width)); s.value = v; s.moved(v); }
        onPressed: m => { if (m.x < 30 && m.x < width * s.value + 2) {} upd(m.x); }
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onWheel: w => { const v = Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))); s.value = v; s.moved(v); }
    }
}
