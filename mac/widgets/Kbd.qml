import QtQuick
import qs.services

// Keycap hint: Kbd { keys: ["Ctrl", "K"] }
Row {
    id: k
    property var keys: []
    property color textColor: Theme.text2
    property color capColor: Theme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.06)
    spacing: 3
    Repeater {
        model: k.keys
        Rectangle {
            required property string modelData
            height: 20
            width: Math.max(20, lbl.implicitWidth + 10)
            radius: 5
            color: k.capColor
            border.width: 1
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)
            T {
                id: lbl
                anchors.centerIn: parent
                text: modelData
                font.pixelSize: 11
                font.weight: Font.Medium
                color: k.textColor
            }
        }
    }
}
