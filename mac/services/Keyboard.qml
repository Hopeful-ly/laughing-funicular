pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Active keyboard layout, for the menu bar input-source indicator.
Singleton {
    id: root
    property string layout: ""
    readonly property string short: {
        const l = layout.toLowerCase();
        if (l.indexOf("persian") >= 0 || l.indexOf("farsi") >= 0) return "FA";
        if (l.indexOf("english") >= 0) return "EN";
        return layout.slice(0, 2).toUpperCase();
    }
    property int count: 1

    function next() { Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]); }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "activelayout") {
                const d = ev.data.split(",");
                root.layout = d.slice(1).join(",");
            }
        }
    }
    Process {
        running: true
        command: ["bash", "-c", "hyprctl devices -j | jq -r '(.keyboards[] | select(.main) | .active_keymap), (.keyboards[] | select(.main) | .layout)' | head -2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                root.layout = l[0] || "";
                root.count = (l[1] || "").split(",").length;
            }
        }
    }
}
