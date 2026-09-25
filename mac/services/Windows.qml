pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Window helpers on top of Hyprland IPC.
Singleton {
    id: root

    readonly property var all: Hyprland.toplevels.values

    function appIdOf(t) {
        if (!t) return "";
        if (t.wayland && t.wayland.appId) return t.wayland.appId;
        return (t.lastIpcObject && t.lastIpcObject.class) || "";
    }
    function addr(t) {
        const a = String(t.address || "");
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function of(appId) { return all.filter(t => appIdOf(t) === appId); }
    function running(appId) { return of(appId).length > 0; }
    function runningAppIds() {
        const out = [];
        for (const t of all) {
            const id = appIdOf(t);
            if (id && out.indexOf(id) < 0) out.push(id);
        }
        return out;
    }

    function focus(t) { Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`); }
    function close(t) { Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr(t)}" })`); }
    function moveHere(t) {
        const ws = Hyprland.focusedWorkspace;
        if (ws) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws.id}, window = "address:${addr(t)}" })`);
    }

    // Dock click: focus the app; if already focused, cycle through its windows.
    function activateApp(appId) {
        const wins = of(appId);
        if (wins.length === 0) return false;
        const active = Hyprland.activeToplevel;
        const idx = wins.indexOf(active);
        if (idx >= 0 && wins.length > 1) focus(wins[(idx + 1) % wins.length]);
        else if (idx < 0) {
            // Prefer a window on the current workspace.
            const ws = Hyprland.focusedWorkspace;
            focus(wins.find(w => w.workspace && ws && w.workspace.id === ws.id) || wins[0]);
        }
        return true;
    }
    function quitApp(appId) { for (const t of of(appId)) close(t); }
}
