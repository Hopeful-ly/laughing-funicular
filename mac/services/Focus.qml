pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Deep Focus: lock the session down to one app.
//   in:  the app's windows move to a "focus" workspace, Hyprland enters the
//        "focus" submap (only media/brightness/lid + Super+Esc work), trackpad
//        workspace swipes are disabled, bar + dock + launcher + notifications
//        go away, Do Not Disturb turns on.
//   out: Super+Esc → hold · type the phrase · wait out the countdown
//        (modules/FocusExit.qml). A timed session that has ended leaves in one
//        click. State lives in Config.focus so a shell reload can't break out.
//   crash safety: Super+Ctrl+Alt+Backspace runs scripts/focus-panic.sh, which
//        only resets Hyprland if the shell is not running.
Singleton {
    id: root

    readonly property var state: Config.focus || ({ active: false })
    readonly property bool active: !!state.active
    readonly property string appId: state.appId || ""
    readonly property string appName: state.appName || ""
    readonly property string entryId: state.entryId || ""
    readonly property real startedAt: state.startedAt || 0
    readonly property int minutes: state.minutes || 0
    readonly property bool timed: minutes > 0
    readonly property real endsAt: timed ? startedAt + minutes * 60000 : 0

    property real now: Date.now()
    Timer { interval: 1000; running: root.active; repeat: true; onTriggered: root.now = Date.now() }
    readonly property int elapsedSec: active ? Math.max(0, Math.floor((now - startedAt) / 1000)) : 0
    readonly property int remainingSec: timed ? Math.max(0, Math.ceil((endsAt - now) / 1000)) : 0
    readonly property bool complete: active && timed && now >= endsAt
    property bool exitOpen: false
    readonly property var focusWindows: active ? Windows.all.filter(t => t.workspace && t.workspace.name === "focus") : []
    readonly property bool appRunning: focusWindows.length > 0

    function fmt(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
        const mm = (h > 0 ? String(m).padStart(2, "0") : String(m));
        return (h > 0 ? h + ":" : "") + mm + ":" + String(s).padStart(2, "0");
    }
    function hyprSubmap(name) { Hyprland.dispatch(`hl.dsp.submap("${name}")`); }
    function lua(code) { luaProc.command = ["hyprctl", "eval", code]; luaProc.running = true; }
    Process { id: luaProc }

    // ---- Enter ------------------------------------------------------------------
    // app: DesktopEntry (may be null) · appId: window class · minutes: 0 = open-ended
    function start(app, appId, minutes) {
        if (active) return;
        let id = appId || "";
        let wins = id ? Windows.of(id) : [];
        if (!wins.length && app) {
            for (const cand of [app.startupClass, app.id]) {
                if (cand && Windows.of(cand).length) { id = cand; wins = Windows.of(cand); break; }
            }
        }
        if (!id) id = app ? (app.startupClass || app.id) : "";
        if (!id) return;
        const mon = Hyprland.focusedMonitor;
        const prevWs = wins.length && wins[0].workspace ? wins[0].workspace.id : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1);
        const others = {};
        for (const m of Hyprland.monitors.values) if (!mon || m.name !== mon.name) others[m.name] = m.activeWorkspace ? m.activeWorkspace.id : 1;

        Config.focus = {
            active: true, appId: id, appName: app ? app.name : Apps.nameForAppId(id), entryId: app ? app.id : "",
            startedAt: Date.now(), minutes: minutes || 0,
            prevWorkspace: prevWs, prevDnd: Config.dnd, monitor: mon ? mon.name : "", otherMonitors: others
        };
        Config.focusMinutes = minutes || 0;
        Config.dnd = true;
        Shell.closeAll();
        applyHyprland(wins, app);
    }

    function applyHyprland(wins, app) {
        // Other monitors show an empty workspace so nothing else is on screen.
        const st = Config.focus;
        for (const name in (st.otherMonitors || {})) {
            Hyprland.dispatch(`hl.dsp.focus({ monitor = "${name}" })`);
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "name:focus-${name}" })`);
        }
        if (st.monitor) Hyprland.dispatch(`hl.dsp.focus({ monitor = "${st.monitor}" })`);
        for (const t of wins) Hyprland.dispatch(`hl.dsp.window.move({ workspace = "name:focus", window = "address:${Windows.addr(t)}" })`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = "name:focus" })`);
        if (wins.length === 0 && app) Apps.launch(app);       // app not running: start it on the focus workspace
        else if (wins.length) Windows.focus(wins[0]);
    }
    // The lockdown follows `active` (persisted), so it is applied on start,
    // released on end, and re-applied when the shell restarts mid-session
    // (settings load asynchronously, so init() alone would miss it).
    onActiveChanged: lockdown(active)
    function lockdown(on) {
        hyprSubmap(on ? "focus" : "reset");
        lua(on ? "hl.config({ gestures = { workspace_swipe_distance = 100000 } })"
               : "hl.config({ gestures = { workspace_swipe_distance = 300 } })");
    }

    // ---- Leave ---------------------------------------------------------------------
    function end() {
        if (!active) return;
        const st = Config.focus;
        exitOpen = false;
        for (const t of focusWindows) Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${st.prevWorkspace || 1}, window = "address:${Windows.addr(t)}" })`);
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${st.prevWorkspace || 1} })`);
        for (const name in (st.otherMonitors || {})) {
            Hyprland.dispatch(`hl.dsp.focus({ monitor = "${name}" })`);
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${st.otherMonitors[name]} })`);
        }
        if (st.monitor) Hyprland.dispatch(`hl.dsp.focus({ monitor = "${st.monitor}" })`);
        Config.dnd = !!st.prevDnd;
        Config.focus = { active: false, lastEnded: Date.now(), lastMinutes: Math.round((Date.now() - (st.startedAt || Date.now())) / 60000) };
    }
    function relaunch() {
        const e = entryId ? Apps.byId(entryId) : Apps.forAppId(appId);
        if (e) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "name:focus" })`); Apps.launch(e); }
    }
    function requestExit() { if (active) { exitOpen = true; } }

    // ---- Keep the lockdown in place -------------------------------------------------
    // Hyprland drops the submap on config reload; re-enter it. Also re-applied
    // when the shell (re)starts while a session is active.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "configreloaded") root.lockdown(root.active);
            else if (ev.name === "submap") {
                // Never let the compositor's submap disagree with the session state.
                if (root.active && ev.data !== "focus") Qt.callLater(() => root.hyprSubmap("focus"));
                else if (!root.active && ev.data === "focus") Qt.callLater(() => root.hyprSubmap("reset"));
            }
        }
    }
    function init() {
        if (active) Config.dnd = true;
        else hyprSubmap("reset");           // stray submap from a crashed session
    }

    IpcHandler {
        target: "focus"
        function ping(): string { return root.active ? "active" : "idle"; }
        function exit(): void { root.requestExit(); }
        function status(): string { return root.active ? root.appName + " · " + root.fmt(root.elapsedSec) : "not in deep focus"; }
        // Deliberately no "end" here: leaving goes through the exit flow.
    }
    GlobalShortcut { name: "focusexit"; description: "Deep Focus: leave (hold, phrase, countdown)"; onPressed: root.requestExit() }
    GlobalShortcut { name: "focusnow"; description: "Deep Focus on the active app"; onPressed: root.startActive() }

    function startActive() {
        if (active) return;
        const t = Hyprland.activeToplevel;
        const id = Windows.appIdOf(t);
        if (!id) return;
        start(Apps.forAppId(id), id, Config.focusMinutes);
    }
}
