pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which panel is open, on which screen, plus IPC + global shortcuts.
//   qs -c mac ipc call shell toggle launcher|clipboard|controlcenter|notifications|shortcuts|wallpapers|windows|calculator|session
//   Hyprland: hl.dsp.global("quickshell:<name>")
Singleton {
    id: root

    // "" | "launcher" | "clipboard" | "controlcenter" | "notifications"
    property string panel: ""
    property string screenName: ""
    property real panelX: 0            // anchor x for panels that open under a bar item
    // Initial view for the launcher: "root" | "wallpapers" | "shortcuts" | "windows" | "calculator"
    property string launcherView: "root"
    property int launcherRequest: 0   // bump to reset launcher state
    // Cmd+Tab-style switcher: opened by Super+Tab, switches on Super release.
    property bool launcherQuick: false
    property int launcherQuickDir: 1
    signal switcherStep(int dir)
    signal activateSelection()          // "press ↵" in the open launcher (IPC/scripting)
    function windowSwitcher(dir) {
        if (panel === "launcher" && launcherView === "windows") { switcherStep(dir); return; }
        launcherQuick = true;
        launcherQuickDir = dir;
        openLauncher("windows");
    }

    function focusedScreen() {
        const m = Hyprland.focusedMonitor;
        return m ? m.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
    }

    function open(name, screen) {
        screenName = screen || focusedScreen();
        menuOpen = false;
        panel = name;
    }

    // Bar + dock windows per screen. Popups share a focus grab with them, so
    // the bar stays clickable while a popup is open.
    property var bars: ({})
    property var docks: ({})
    function registerBar(name, win) { if (!name) return; const b = Object.assign({}, bars); b[name] = win; bars = b; }
    function registerDock(name, win) { if (!name) return; const d = Object.assign({}, docks); d[name] = win; docks = d; }
    function closeAll() { close(); hideMenu(); }
    function close() { panel = ""; }

    // Run fn after overlays release the keyboard. Focusing a window while a
    // popup still holds exclusive keyboard focus gets undone when the popup
    // lets go (Hyprland restores the previously focused window).
    property var _later: []
    function later(fn) { _later = _later.concat([fn]); laterTimer.restart(); }
    Timer {
        id: laterTimer
        interval: 90
        onTriggered: { const q = root._later; root._later = []; for (const f of q) f(); }
    }
    function toggle(name, screen) {
        const s = screen || focusedScreen();
        if (panel === name && screenName === s) close();
        else open(name, s);
    }
    function openLauncher(view, screen) {
        if (view !== "windows" || !launcherQuick) launcherQuick = false;
        launcherView = view || "root";
        launcherRequest++;
        open("launcher", screen);
    }
    function toggleLauncher(view) {
        view = view || "root";
        if (panel === "launcher" && launcherView === view) close();
        else openLauncher(view);
    }
    function isOpen(name, screen) { return panel === name && screenName === screen; }

    // ---- Context menu (dock, tray, apple menu) --------------------------
    property var menuItems: []
    property point menuPos: Qt.point(0, 0)
    property string menuScreen: ""
    property bool menuOpen: false
    property bool menuAbove: false      // open upwards (dock)
    function showMenu(screen, x, y, items, above) {
        menuItems = items;
        menuPos = Qt.point(x, y);
        menuScreen = screen;
        menuAbove = !!above;
        panel = "";
        menuOpen = true;
    }
    function hideMenu() { menuOpen = false; }

    // ---- Confirmation dialog (shut down, restart, ...) -------------------
    property var dialog: null           // { title, body, icon, confirm, destructive, action, countdown }
    function ask(d) { dialog = d; }

    // ---- Session helpers -----------------------------------------------
    function run(cmd) { Quickshell.execDetached(["bash", "-c", cmd]); }
    function dispatch(lua) { Hyprland.dispatch(lua); }
    function lock() { Lock.lock(); }
    // Animated "hand spinning a pen" + fastfetch, in a floating terminal
    // (window rule for class mac-about lives in hypr/rules.lua).
    function about() { Quickshell.execDetached([Config.terminal, "--class", "mac-about", "--title", "About This Computer", "-e", "python3", Quickshell.shellPath("scripts/about.py")]); }
    function sleep() { Lock.lock(); run("sleep 0.5; systemctl suspend"); }
    function askShutdown() { ask({ title: "Are you sure you want to shut down your computer now?", icon: "power_settings_new", confirm: "Shut Down", countdown: 60, action: () => run("systemctl poweroff") }); }
    function askRestart() { ask({ title: "Are you sure you want to restart your computer now?", icon: "restart_alt", confirm: "Restart", countdown: 60, action: () => run("systemctl reboot") }); }
    function askLogout() { ask({ title: "Are you sure you want to quit all applications and log out now?", icon: "logout", confirm: "Log Out", countdown: 60, action: () => dispatch("hl.dsp.exit()") }); }

    function sessionMenu(screen, x, y) {
        showMenu(screen, x, y, [
            { text: "About This Computer", icon: "info", action: () => about() },
            { separator: true },
            { text: "Control Center", icon: "tune", shortcut: "Super A", action: () => open("controlcenter", screen) },
            { text: "Keyboard Shortcuts", icon: "keyboard", shortcut: "Super /", action: () => openLauncher("shortcuts", screen) },
            { text: "Change Wallpaper…", icon: "wallpaper", shortcut: "Super ⇧ W", action: () => openLauncher("wallpapers", screen) },
            { text: "Reload Shell", icon: "refresh", action: () => Quickshell.reload(true) },
            { separator: true },
            { text: "Sleep", icon: "bedtime", action: () => sleep() },
            { text: "Restart…", icon: "restart_alt", action: () => askRestart() },
            { text: "Shut Down…", icon: "power_settings_new", action: () => askShutdown() },
            { separator: true },
            { text: "Lock Screen", icon: "lock", shortcut: "Super L", action: () => lock() },
            { text: "Log Out…", icon: "logout", shortcut: "Super ⇧ L", action: () => askLogout() }
        ], false);
    }

    // ---- IPC -------------------------------------------------------------
    IpcHandler {
        target: "shell"
        function toggle(name: string): void {
            switch (name) {
            case "launcher": root.toggleLauncher("root"); break;
            case "shortcuts": case "wallpapers": case "windows": case "calculator": root.toggleLauncher(name); break;
            case "system": case "battery": case "disk": root.toggle(name); break;
            case "session": root.sessionMenu(root.focusedScreen(), 8, 0); break;
            default: root.toggle(name);
            }
        }
        function activate(): void { root.activateSelection(); }
        function close(): void { root.close(); root.hideMenu(); root.dialog = null; }
        function reloadTheme(): void { Theme.analyze(); }
    }
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Wallpaper.set(path); }
        function random(): void { Wallpaper.random(); }
        function get(): string { return Wallpaper.current; }
    }

    // ---- Hyprland global shortcuts (bound in hypr/keybinds.lua) ----------
    GlobalShortcut { name: "launcher"; description: "Open launcher"; onPressed: root.toggleLauncher("root") }
    GlobalShortcut { name: "clipboard"; description: "Clipboard history"; onPressed: root.toggle("clipboard") }
    GlobalShortcut { name: "calculator"; description: "Calculator"; onPressed: root.toggleLauncher("calculator") }
    GlobalShortcut { name: "windows"; description: "Switch windows (next)"; onPressed: root.windowSwitcher(1) }
    GlobalShortcut { name: "windowsPrev"; description: "Switch windows (previous)"; onPressed: root.windowSwitcher(-1) }
    GlobalShortcut { name: "shortcuts"; description: "Keyboard shortcuts"; onPressed: root.toggleLauncher("shortcuts") }
    GlobalShortcut { name: "wallpapers"; description: "Wallpaper picker"; onPressed: root.toggleLauncher("wallpapers") }
    GlobalShortcut { name: "controlcenter"; description: "Control Center"; onPressed: root.toggle("controlcenter") }
    GlobalShortcut { name: "notifications"; description: "Notification Center"; onPressed: root.toggle("notifications") }
    GlobalShortcut { name: "session"; description: "Session menu"; onPressed: root.sessionMenu(root.focusedScreen(), 8, 0) }
    GlobalShortcut { name: "logout"; description: "Log out (confirm)"; onPressed: root.askLogout() }
    GlobalShortcut { name: "dnd"; description: "Toggle Do Not Disturb"; onPressed: Config.dnd = !Config.dnd }
}
