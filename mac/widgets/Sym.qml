import QtQuick
import qs.services

// Material Symbols Rounded glyph (closest free match for SF Symbols).
Text {
    id: s
    property string name: ""
    property real size: 18
    property bool filled: false
    property int weight: 400
    text: name
    color: Theme.text
    font.family: Config.iconFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": weight, "opsz": Math.max(20, Math.min(48, size)), "GRAD": 0 })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
}
