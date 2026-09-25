import QtQuick
import qs.services

// Tahoe slider: thin track, white fill, round knob, small/large end glyphs.
Item {
    id: s
    property real value: 0.5
    property string iconLow: "brightness_low"
    property string iconHigh: "brightness_high"
    signal moved(real v)
    implicitHeight: 22

    Sym { id: lo; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; name: s.iconLow; size: 15; filled: true; color: Theme.text2 }
    Sym { id: hi; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: s.iconHigh; size: 18; filled: true; color: Theme.text2 }

    Item {
        id: area
        anchors.left: lo.right; anchors.right: hi.left
        anchors.leftMargin: 10; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
            Rectangle {
                height: parent.height; radius: 3
                width: knob.x + knob.width / 2
                color: Theme.dark ? "#f2f2f7" : "#ffffff"
            }
        }
        Rectangle {
            id: knob
            width: 20; height: 20; radius: 10
            anchors.verticalCenter: parent.verticalCenter
            x: (area.width - width) * Math.max(0, Math.min(1, s.value))
            Behavior on x { enabled: !ma.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.08)
            scale: ma.pressed ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            function upd(x) { const v = Math.max(0, Math.min(1, (x - 6 - knob.width / 2) / (area.width - knob.width))); s.value = v; s.moved(v); }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
            onWheel: w => { const v = Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))); s.value = v; s.moved(v); }
        }
    }
}
