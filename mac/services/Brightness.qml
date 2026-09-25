pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight via brightnessctl. Hyprland brightness keys call
// `qs -c mac ipc call brightness up|down` so the OSD can show it.
Singleton {
    id: root
    property real value: 1
    property int max: 1
    property bool available: false
    signal changedByUser()

    function refresh() { getter.running = true; }
    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(v * 100) + "%"]);
    }
    function step(d) {
        stepper.command = ["brightnessctl", "-m", "-e4", "-n2", "set", Math.abs(d) + "%" + (d > 0 ? "+" : "-")];
        stepper.running = true;
    }

    function parse(t) {
        const p = t.trim().split(",");
        if (p.length >= 5) {
            available = true;
            max = +p[4];
            value = (+p[2]) / max;
        }
    }
    Process { id: getter; command: ["brightnessctl", "-m"]; stdout: StdioCollector { onStreamFinished: root.parse(text) } }
    Process { id: stepper; stdout: StdioCollector { onStreamFinished: { root.parse(text); root.changedByUser(); } } }

    IpcHandler {
        target: "brightness"
        function up(): void { root.step(5); }
        function down(): void { root.step(-5); }
        function changed(): void { getter.running = true; root.changedByUser(); }
    }
    Component.onCompleted: refresh()
}
