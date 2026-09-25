import QtQuick
import Quickshell.Widgets
import qs.services

// Launcher row icon: app icon (path) or symbol on a coloured rounded tile.
Item {
    id: ic
    property string path: ""
    property string sym: ""
    property color tint: "#8e8e93"
    property int size: 26
    width: size; height: size
    IconImage { anchors.fill: parent; visible: ic.path !== ""; source: ic.path; asynchronous: true }
    Rectangle {
        anchors.fill: parent
        visible: ic.path === "" && ic.sym !== ""
        radius: ic.size * 0.26
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(ic.tint, 1.25) }
            GradientStop { position: 1; color: ic.tint }
        }
        Sym { anchors.centerIn: parent; name: ic.sym; size: ic.size * 0.62; filled: true; color: "white" }
    }
}
