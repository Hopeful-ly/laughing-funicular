import QtQuick
import qs.services

// Footer hint: "Paste  [↵]"
Row {
    id: h
    property string label: ""
    property var keys: []
    property bool strong: false
    spacing: 7
    T {
        anchors.verticalCenter: parent.verticalCenter
        text: h.label
        font.pixelSize: 12
        font.weight: h.strong ? Font.DemiBold : Font.Normal
        color: h.strong ? Theme.text : Theme.text2
    }
    Kbd { anchors.verticalCenter: parent.verticalCenter; keys: h.keys }
}
