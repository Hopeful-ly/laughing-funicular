pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Clipboard history on top of cliphist, plus pins that survive wipes.
Singleton {
    id: root

    property var entries: []          // [{ id, line, preview, kind, meta }]
    property bool loading: false
    readonly property string cacheDir: Quickshell.cachePath("clip")
    readonly property string pinDir: Quickshell.dataPath("clip-pins")

    // ---- Pins --------------------------------------------------------------
    FileView {
        id: pinFile
        path: Quickshell.dataPath("clip-pins.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter { id: pinData; property var pins: [] }
    }
    readonly property var pins: pinData.pins

    function classify(preview) {
        let m = preview.match(/^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/);
        if (m) return { kind: "image", meta: { size: m[1], fmt: m[2], w: +m[3], h: +m[4] } };
        m = preview.match(/^\[\[ binary data (.+?) (\w+).*\]\]$/);
        if (m) return { kind: "binary", meta: { size: m[1], fmt: m[2] } };
        const t = preview.trim();
        if (/^https?:\/\/\S+$/.test(t)) return { kind: "link", meta: {} };
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(t) || /^rgba?\(/i.test(t)) return { kind: "color", meta: {} };
        if (/^(\/|~\/|file:\/\/)\S+$/.test(t)) return { kind: "file", meta: {} };
        return { kind: "text", meta: {} };
    }

    function refresh() { loading = true; lister.running = true; }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const preview = line.slice(tab + 1);
                    const c = root.classify(preview);
                    out.push({ id: line.slice(0, tab), line: line, preview: preview, kind: c.kind, meta: c.meta });
                }
                root.entries = out;
                root.loading = false;
            }
        }
    }

    // ---- Decoding (text preview + image files) ----------------------------
    function imagePath(e) { return cacheDir + "/" + e.id + "." + (e.meta.fmt || "png"); }

    property var _textCache: ({})
    signal decoded(string id, string text)
    signal imageReady(string id, string path)

    function decodeText(e) {
        if (_textCache[e.id] !== undefined) { decoded(e.id, _textCache[e.id]); return; }
        const p = textDecoder.createObject(root, { entryId: e.id });
        p.running = true;
    }
    Component {
        id: textDecoder
        Process {
            id: dp
            property string entryId
            command: ["bash", "-c", "cliphist decode \"$1\" | head -c 200000", "_", entryId]
            stdout: StdioCollector {
                onStreamFinished: {
                    root._textCache[dp.entryId] = text;
                    root.decoded(dp.entryId, text);
                    dp.destroy();
                }
            }
        }
    }
    function decodeImage(e) {
        const p = imgDecoder.createObject(root, { entryId: e.id, out: imagePath(e) });
        p.running = true;
    }
    Component {
        id: imgDecoder
        Process {
            property string entryId
            property string out
            command: ["bash", "-c", "mkdir -p \"$(dirname \"$2\")\"; [ -s \"$2\" ] || cliphist decode \"$1\" > \"$2\"", "_", entryId, out]
            onExited: { root.imageReady(entryId, out); destroy(); }
        }
    }

    // ---- Actions -----------------------------------------------------------
    function copy(e) {
        if (e.pid !== undefined) {
            if (e.kind === "image") Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < \"$1\"", "_", e.file]);
            else Quickshell.execDetached(["wl-copy", "--", e.text]);
        } else {
            Quickshell.execDetached(["bash", "-c", "cliphist decode \"$1\" | wl-copy", "_", e.id]);
        }
    }
    // Copy, then send Ctrl+V (Ctrl+Shift+V in terminals) to the focused window.
    function paste(e) {
        copy(e);
        pasteTimer.restart();
    }
    function sendPaste() { pasteTimer.restart(); }
    Timer {
        id: pasteTimer
        interval: 180
        onTriggered: {
            const t = Hyprland.activeToplevel;
            const cls = t && t.lastIpcObject ? (t.lastIpcObject.class || "") : "";
            const term = Config.terminalClasses.indexOf(cls) >= 0;
            Hyprland.dispatch(`hl.dsp.send_shortcut({ mods = "${term ? "CTRL SHIFT" : "CTRL"}", key = "V" })`);
        }
    }

    function remove(e) {
        if (e.pid !== undefined) { unpin(e); return; }
        entries = entries.filter(x => x.id !== e.id);
        Quickshell.execDetached(["bash", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "_", e.line]);
    }
    function wipe() {
        entries = [];
        _textCache = {};
        Quickshell.execDetached(["bash", "-c", "cliphist wipe; rm -rf \"$1\"", "_", cacheDir]);
    }

    function isPinned(e) {
        if (e.pid !== undefined) return true;
        return pins.some(p => p.src === e.id);
    }
    function pin(e) {
        if (isPinned(e)) return;
        const pid = Date.now().toString(36);
        if (e.kind === "image") {
            const file = pinDir + "/" + pid + "." + (e.meta.fmt || "png");
            const p = pinner.createObject(root, { pid: pid, entry: e, file: file });
            p.running = true;
        } else {
            const p = textPinner.createObject(root, { pid: pid, entry: e });
            p.running = true;
        }
    }
    function unpin(e) {
        const pid = e.pid !== undefined ? e.pid : (pins.find(p => p.src === e.id) || {}).pid;
        const hit = pins.find(p => p.pid === pid);
        if (hit && hit.file) Quickshell.execDetached(["rm", "-f", hit.file]);
        pinData.pins = pins.filter(p => p.pid !== pid);
    }
    function togglePin(e) { if (isPinned(e)) unpin(e); else pin(e); }
    function addPin(obj) { pinData.pins = [obj].concat(pins); }

    Component {
        id: pinner
        Process {
            property string pid
            property var entry
            property string file
            command: ["bash", "-c", "mkdir -p \"$(dirname \"$2\")\"; cliphist decode \"$1\" > \"$2\"", "_", entry.id, file]
            onExited: {
                root.addPin({ pid: pid, src: entry.id, kind: "image", file: file, preview: entry.preview, meta: entry.meta, time: Date.now() });
                destroy();
            }
        }
    }
    Component {
        id: textPinner
        Process {
            id: tp
            property string pid
            property var entry
            command: ["cliphist", "decode", entry.id]
            stdout: StdioCollector {
                onStreamFinished: {
                    const e = tp.entry;
                    root.addPin({ pid: tp.pid, src: e.id, kind: e.kind, text: text, preview: e.preview, meta: e.meta, time: Date.now() });
                    tp.destroy();
                }
            }
        }
    }

    function saveImage(e) {
        const src = e.pid !== undefined ? e.file : imagePath(e);
        const dest = Quickshell.env("HOME") + "/Pictures/Clipboard-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".png";
        Quickshell.execDetached(["bash", "-c", "mkdir -p ~/Pictures; [ -s \"$1\" ] || cliphist decode \"$3\" > \"$1\"; cp \"$1\" \"$2\" && notify-send -a Clipboard -i image-x-generic 'Image saved' \"$2\"", "_", src, dest, e.id || ""]);
    }
}
