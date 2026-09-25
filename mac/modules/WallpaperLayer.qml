import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Desktop background with a cross-fade on change (replaces hyprpaper).
PanelWindow {
    id: w
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "mac-wallpaper"

    property string shown: ""
    property bool flip: false

    function apply(path) {
        const next = flip ? a : b;
        next.source = "file://" + path;
    }
    Component.onCompleted: apply(Wallpaper.current)
    Connections { target: Wallpaper; function onCurrentChanged() { w.apply(Wallpaper.current); } }

    Image {
        id: a
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: w.width * (w.screen ? w.screen.devicePixelRatio : 1)
        opacity: w.flip ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && w.flip) w.flip = false
    }
    Image {
        id: b
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize.width: w.width * (w.screen ? w.screen.devicePixelRatio : 1)
        opacity: w.flip ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
        onStatusChanged: if (status === Image.Ready && !w.flip) w.flip = true
    }
}
