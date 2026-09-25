pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Current wallpaper + the list of available ones. Rendering is done by
// modules/WallpaperLayer.qml, colours are extracted by Theme.
Singleton {
    id: root
    readonly property string current: Config.wallpaper !== "" ? Config.wallpaper : fallback
    readonly property string fallback: Config.wallpaperDir + "/macos-tahoe-dark.jpg"
    property var list: []

    function set(path) { Config.wallpaper = path; }
    function random() {
        if (list.length < 2) return;
        let p;
        do { p = list[Math.floor(Math.random() * list.length)]; } while (p === current);
        set(p);
    }
    function refresh() { lister.running = true; }

    Process {
        id: lister
        command: ["bash", "-c", "find -L \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) ! -path '*/.*' | sort", "_", Config.wallpaperDir]
        stdout: StdioCollector {
            onStreamFinished: root.list = text.split("\n").filter(s => s.length > 0)
        }
    }
    Component.onCompleted: refresh()
}
