import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Volume / brightness HUD (Tahoe-style capsule near the top-right).
PanelWindow {
    id: w
    readonly property string sname: screen ? screen.name : ""
    property string kind: "volume"
    property bool shown: false
    property real value: kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value

    visible: shown || t > 0.01
    anchors { top: true; right: true }
    margins { top: Config.barHeight + 6; right: 12 }
    implicitWidth: 300
    implicitHeight: 64
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mac-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: w.shown ? 180 : 260; easing.type: Easing.OutCubic } }

    function show(k) {
        if (sname !== Shell.focusedScreen()) return;
        if (Shell.isOpen("controlcenter", sname)) return;
        kind = k; shown = true; hide.restart();
    }
    Timer { id: hide; interval: 1500; onTriggered: w.shown = false }

    property bool ready: false
    Timer { interval: 1500; running: true; onTriggered: w.ready = true }
    Connections {
        target: Audio.ready ? Audio.sink.audio : null
        function onVolumeChanged() { if (w.ready) w.show("volume"); }
        function onMutedChanged() { if (w.ready) w.show("volume"); }
    }
    Connections { target: Brightness; function onChangedByUser() { w.show("brightness"); } }

    Glass {
        anchors.fill: parent
        anchors.margins: 6
        radius: height / 2
        tint: Theme.glassThick
        opacity: w.t
        scale: 0.94 + 0.06 * w.t
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            Sym {
                name: w.kind === "volume" ? Audio.icon() : "light_mode"
                size: 20; filled: true
                Layout.preferredWidth: 22
            }
            Rectangle {
                Layout.fillWidth: true
                height: 6; radius: 3
                color: Theme.field
                Rectangle {
                    height: parent.height; radius: 3
                    width: parent.width * Math.max(0, Math.min(1, w.value))
                    color: Theme.text
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
            T {
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: Math.round(w.value * 100)
                font.pixelSize: 12; font.features: { "tnum": 1 }
                color: Theme.text2
            }
        }
    }
}
