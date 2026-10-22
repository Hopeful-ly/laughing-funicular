pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keyboard shortcut reference. Hyprland binds are read live from
// `hyprctl binds -j`; descriptions use "Category: Text" (see keybinds.lua).
// In-shell shortcuts are listed statically below.
Singleton {
    id: root
    property var hypr: []      // [{ category, text, keys: [...] }]

    readonly property var shell: [
        { category: "Launcher", text: "Move selection", keys: ["↑", "↓"] },
        { category: "Launcher", text: "Move selection (Tab / back)", keys: ["Tab", "⇧Tab"] },
        { category: "Windows", text: "Hold Super: Tab / ⇧Tab to pick, release to switch", keys: ["Super", "Tab"] },
        { category: "Launcher", text: "Open / run selected", keys: ["↵"] },
        { category: "Launcher", text: "Show actions for selection", keys: ["Ctrl", "K"] },
        { category: "Launcher", text: "Quick-open result 1–9", keys: ["Alt", "1…9"] },
        { category: "Launcher", text: "Back / clear / close", keys: ["Esc"] },
        { category: "Launcher", text: "Pin app to Dock", keys: ["Ctrl", "P"] },
        { category: "Launcher", text: "Run command in terminal (Ctrl ↵: background)", keys: [">", "cmd"] },
        { category: "Launcher", text: "Search the web", keys: ["?", "query"] },
        { category: "Launcher", text: "Search files", keys: ["/", "name"] },
        { category: "Launcher", text: "Calculator (type any maths)", keys: ["=", "2^10"] },
        { category: "Deep Focus", text: "Pick an app (launcher: Ctrl 1–5 = duration)", keys: ["Super", "Ctrl", "D"] },
        { category: "Deep Focus", text: "Leave: hold Space · type the phrase · wait", keys: ["Super", "Esc"] },
        { category: "Deep Focus", text: "Emergency release (only if the shell died)", keys: ["Super", "Ctrl", "Alt", "⌫"] },
        { category: "Clipboard", text: "Paste selected item", keys: ["↵"] },
        { category: "Clipboard", text: "Copy without pasting", keys: ["Ctrl", "↵"] },
        { category: "Clipboard", text: "Pin / unpin", keys: ["Ctrl", "P"] },
        { category: "Clipboard", text: "Delete item", keys: ["Ctrl", "D"] },
        { category: "Clipboard", text: "Filter: All · Pinned · Text · Images · Links", keys: ["Tab"] },
        { category: "Clipboard", text: "Save image to Pictures", keys: ["Ctrl", "S"] },
        { category: "Clipboard", text: "Clear history (keeps pins)", keys: ["Ctrl", "⇧", "⌫"] },
        { category: "Control Center", text: "Wi-Fi · Bluetooth · Tailscale · Sound pages", keys: ["W", "B", "T", "S"] },
        { category: "Control Center", text: "Tailscale: switch account · add account · connect", keys: ["1–9", "N", "C"] },
        { category: "Control Center", text: "Do Not Disturb · Keep Awake", keys: ["D", "A"] },
        { category: "Control Center", text: "Volume up / down · mute", keys: ["↑", "↓", "M"] },
        { category: "Notifications", text: "Dismiss selected · clear all", keys: ["Del", "Ctrl ⌫"] },
        { category: "Dock", text: "Open / focus / cycle windows", keys: ["Click"] },
        { category: "Dock", text: "New window", keys: ["Middle-click"] },
        { category: "Dock", text: "Window list, pin, quit", keys: ["Right-click"] },
        { category: "Menu Bar", text: "Switch occupied workspaces", keys: ["Scroll"] },
        { category: "Menu Bar", text: "CPU · Disk · Battery popups", keys: ["Click"] },
        { category: "System", text: "Battery: cycle / pick power mode", keys: ["P", "1", "2", "3"] },
        { category: "System", text: "CPU: more details in btop", keys: ["M"] },
        { category: "System", text: "Disk: empty Trash · rescan · duf", keys: ["E", "R", "M"] }
    ]
    readonly property var all: hypr.concat(shell)

    readonly property var modNames: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "⇧"]]
    function prettyKey(k) {
        const map = { "Space": "Space", "Return": "↵", "grave": "`", "slash": "/", "left": "←", "right": "→", "up": "↑", "down": "↓",
                      "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑", "mouse:272": "Drag", "mouse:273": "Right-drag", "Print": "PrtSc",
                      "comma": ",", "period": ".", "Tab": "Tab", "Escape": "Esc", "BackSpace": "⌫" };
        if (map[k]) return map[k];
        if (k.startsWith("XF86")) return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2");
        return k.length === 1 ? k.toUpperCase() : k;
    }

    function refresh() { proc.running = true; }
    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let arr = [];
                try { arr = JSON.parse(text); } catch (e) { return; }
                const out = [];
                const seen = {};
                for (const b of arr) {
                    if (!b.has_description || !b.description) continue;
                    const d = b.description;
                    const i = d.indexOf(":");
                    const cat = i > 0 ? d.slice(0, i).trim() : "General";
                    const txt = i > 0 ? d.slice(i + 1).trim() : d;
                    const keys = [];
                    for (const m of root.modNames) if (b.modmask & m[0]) keys.push(m[1]);
                    keys.push(root.prettyKey(b.key));
                    // Collapse numbered series (workspace 1..10) into one row.
                    const series = txt.replace(/\b\d+\b/, "N");
                    const sk = cat + series + keys.slice(0, -1).join("+");
                    if (/^[0-9]$/.test(b.key) && series !== txt) {
                        if (seen[sk]) continue;
                        seen[sk] = true;
                        keys[keys.length - 1] = "1…0";
                        out.push({ category: cat, text: series.replace("N", "1–10"), keys: keys });
                        continue;
                    }
                    out.push({ category: cat, text: txt, keys: keys });
                }
                root.hypr = out;
            }
        }
    }
    Component.onCompleted: refresh()
}
