pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Colour system derived from the wallpaper, modelled on macOS materials.
//  - appearance "auto": dark/light follows wallpaper brightness
//  - accent: most vivid wallpaper colour, normalised to a system-like tone
//  - menu bar text colour follows brightness of the top strip of the wallpaper
// (Hyprland window borders are disabled; focus is shown by opacity.)
Singleton {
    id: root

    // ---- Wallpaper analysis ---------------------------------------------
    property color wallMean: "#2a3890"
    property color wallTop: "#10127f"
    property color wallBottom: "#182778"
    property color wallVivid: "#3a5cd0"
    property bool analyzed: false

    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

    readonly property bool dark: Config.appearance === "dark" ? true
                               : Config.appearance === "light" ? false
                               : lum(wallMean) < 0.56
    readonly property bool barOnLight: !Config.barGlass && lum(wallTop) > 0.62

    // ---- Accent ----------------------------------------------------------
    readonly property color accent: {
        const c = wallVivid;
        const s = Math.max(0.55, Math.min(0.9, c.hslSaturation));
        const l = dark ? 0.62 : 0.50;
        return Qt.hsla(c.hslHue < 0 ? 0.58 : c.hslHue, c.hslSaturation < 0.12 ? 0.0 : s, l, 1);
    }
    readonly property color accentText: lum(accent) > 0.6 ? "#1d1d1f" : "#ffffff"
    readonly property color systemRed: dark ? "#ff453a" : "#ff3b30"
    readonly property color systemGreen: dark ? "#30d158" : "#28cd41"
    readonly property color systemOrange: dark ? "#ff9f0a" : "#ff9500"
    readonly property color systemYellow: dark ? "#ffd60a" : "#ffcc00"

    // ---- Materials (glass) ----------------------------------------------
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t); }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    readonly property color _baseDark: Qt.rgba(0.12, 0.12, 0.14, 1)
    readonly property color _baseLight: Qt.rgba(0.965, 0.965, 0.975, 1)
    // A tint of the wallpaper bleeds into the glass, as with macOS vibrancy.
    readonly property color glass: alpha(mix(dark ? _baseDark : _baseLight, wallMean, dark ? 0.16 : 0.08), dark ? 0.58 : 0.66)
    readonly property color glassThick: alpha(mix(dark ? _baseDark : _baseLight, wallMean, dark ? 0.12 : 0.05), dark ? 0.80 : 0.84)
    readonly property color glassDock: alpha(mix(dark ? _baseDark : _baseLight, wallBottom, 0.10), dark ? 0.38 : 0.42)
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color tileHover: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.055)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color selection: alpha(accent, dark ? 0.85 : 0.9)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color rimTop: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.9)
    readonly property color rimBottom: dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.35)
    readonly property color outline: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.45 : 0.22)
    readonly property color field: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.045)

    // ---- Text -------------------------------------------------------------
    readonly property color text: dark ? "#f5f5f7" : "#1d1d1f"
    readonly property color text2: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.62) : Qt.rgba(60/255, 60/255, 67/255, 0.68)
    readonly property color text3: dark ? Qt.rgba(235/255, 235/255, 245/255, 0.34) : Qt.rgba(60/255, 60/255, 67/255, 0.36)
    readonly property color barText: barOnLight ? "#1d1d1f" : "#ffffff"
    readonly property color barText2: barOnLight ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.72)
    readonly property color barHover: barOnLight ? Qt.rgba(0, 0, 0, 0.09) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color barShadow: barOnLight ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.35)

    // ---- Metrics ----------------------------------------------------------
    readonly property int radiusPanel: 22
    readonly property int radiusWindow: 16
    readonly property int radiusTile: 14
    readonly property int radiusRow: 9
    readonly property int animFast: 140
    readonly property int animNormal: 220
    readonly property int animSlow: 320

    // ---- Wallpaper analysis process --------------------------------------
    function init() { analyze(); }
    function analyze() { analyzer.running = false; analyzer.running = true; }

    Connections {
        target: Wallpaper
        function onCurrentChanged() { root.analyze(); }
    }

    Process {
        id: analyzer
        command: ["bash", Quickshell.shellPath("scripts/analyze-wallpaper.sh"), Wallpaper.current]
        stdout: StdioCollector {
            onStreamFinished: {
                const pal = [];
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/);
                    const rgb = (a) => Qt.rgba(+a[1] / 255, +a[2] / 255, +a[3] / 255, 1);
                    if (p[0] === "mean") root.wallMean = rgb(p);
                    else if (p[0] === "top") root.wallTop = rgb(p);
                    else if (p[0] === "bottom") root.wallBottom = rgb(p);
                    else if (p[0] === "palette") pal.push({ n: +p[1], c: Qt.color(p[2]) });
                }
                // Vividness: saturation weighted by share, penalising near-black/white.
                let best = null, bestScore = -1;
                const total = pal.reduce((s, x) => s + x.n, 0) || 1;
                for (const x of pal) {
                    const l = x.c.hslLightness;
                    const mid = 1 - Math.abs(l - 0.5) * 1.6;
                    const score = x.c.hslSaturation * Math.max(0.05, mid) * Math.sqrt(x.n / total);
                    if (score > bestScore) { bestScore = score; best = x.c; }
                }
                if (best) root.wallVivid = best;
                root.analyzed = true;
            }
        }
    }

}
