pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings (~/.local/state/quickshell/.../settings.json).
// Everything here can also be changed from the UI.
Singleton {
    id: root

    // ---- Static settings (edit here) ------------------------------------
    readonly property string fontFamily: "Inter Variable"
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property string monoFont: "monospace"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/wallpapers/walls"
    readonly property string terminal: "kitty"
    readonly property string fileManager: "nautilus"
    readonly property int barHeight: 32
    readonly property var terminalClasses: ["kitty", "Alacritty", "foot", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "konsole"]

    // ---- Persisted state -------------------------------------------------
    property alias wallpaper: adapter.wallpaper
    property alias appearance: adapter.appearance       // "auto" | "dark" | "light"
    property alias dnd: adapter.dnd
    property alias dockPinned: adapter.dockPinned
    property alias dockAutohide: adapter.dockAutohide   // "smart" | "always" | "never"
    property alias dockMagnify: adapter.dockMagnify
    property alias barGlass: adapter.barGlass           // false = transparent like Tahoe
    property alias clock24h: adapter.clock24h
    property alias keepAwake: adapter.keepAwake
    // Deep Focus (services/Focus.qml). Persisted so a shell reload can't end it.
    property alias focus: adapter.focus
    property alias focusMinutes: adapter.focusMinutes          // last chosen duration, 0 = open-ended
    property alias focusExitHold: adapter.focusExitHold        // seconds to hold before leaving
    property alias focusExitPhrase: adapter.focusExitPhrase    // must be typed exactly
    property alias focusExitCountdown: adapter.focusExitCountdown

    FileView {
        id: file
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: adapter
            property string wallpaper: ""
            property string appearance: "auto"
            property bool dnd: false
            property list<string> dockPinned: ["org.gnome.Nautilus", "zen", "kitty", "dev.zed.Zed", "cursor", "obsidian", "org.telegram.desktop", "discord", "com.anthropic.Claude", "steam"]
            property string dockAutohide: "smart"
            property bool dockMagnify: true
            property bool barGlass: false
            property bool clock24h: true
            property bool keepAwake: false
            property var focus: ({ active: false })
            property int focusMinutes: 50
            property int focusExitHold: 3
            property string focusExitPhrase: "I am choosing to leave deep focus"
            property int focusExitCountdown: 20
        }
    }

    function togglePin(id) {
        const list = Array.from(dockPinned);
        const i = list.indexOf(id);
        if (i >= 0) list.splice(i, 1); else list.push(id);
        dockPinned = list;
    }
    function isPinned(id) { return Array.from(dockPinned).indexOf(id) >= 0; }
}
