pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Built-in launcher commands. `color` tints the rounded icon tile.
Singleton {
    id: root
    function sc(k) { return k; }
    readonly property var list: [
        { id: "focus", title: "Deep Focus", sub: "Lock in on one app — everything else goes away", icon: "center_focus_strong", color: "#ff375f", keys: ["Super", "⇧", "D"], kw: "focus mode lock distraction pomodoro concentrate", view: "focus" },
        { id: "clipboard", title: "Clipboard History", sub: "Search, paste, pin and delete copied items", icon: "content_paste", color: "#ff9f0a", keys: ["Super", "V"], kw: "copy paste history", run: () => Shell.open("clipboard") },
        { id: "windows", title: "Switch Windows", sub: "Search all open windows", icon: "select_window", color: "#0a84ff", keys: ["Super", "Tab"], kw: "window switcher focus", view: "windows" },
        { id: "shortcuts", title: "Keyboard Shortcuts", sub: "Every shortcut, searchable", icon: "keyboard", color: "#8e8e93", keys: ["Super", "/"], kw: "keybinds help cheatsheet hotkeys", view: "shortcuts" },
        { id: "wallpapers", title: "Change Wallpaper", sub: "Pick a desktop picture — theme follows it", icon: "wallpaper", color: "#5e5ce6", keys: ["Super", "⇧", "W"], kw: "background desktop picture theme", view: "wallpapers" },
        { id: "randomwall", title: "Random Wallpaper", sub: "Shuffle desktop picture", icon: "shuffle", color: "#5e5ce6", kw: "background shuffle", run: () => Wallpaper.random() },
        { id: "appearance", title: "Toggle Appearance", sub: () => "Currently " + Config.appearance + " · Auto → Dark → Light", icon: "contrast", color: "#636366", kw: "dark mode light theme", run: () => Config.appearance = Config.appearance === "auto" ? "dark" : Config.appearance === "dark" ? "light" : "auto", stay: true },
        { id: "dnd", title: "Toggle Do Not Disturb", sub: () => Config.dnd ? "On" : "Off", icon: "dark_mode", color: "#5e5ce6", keys: ["Super", "⇧", "N"], kw: "focus notifications silence", run: () => Config.dnd = !Config.dnd, stay: true },
        { id: "awake", title: "Toggle Keep Awake", sub: () => Config.keepAwake ? "On — screen won't sleep" : "Off", icon: "coffee", color: "#a2845e", kw: "caffeine idle inhibit", run: () => Config.keepAwake = !Config.keepAwake, stay: true },
        { id: "cc", title: "Control Center", sub: "Wi-Fi, Bluetooth, sound, display", icon: "tune", color: "#8e8e93", keys: ["Super", "A"], kw: "settings wifi bluetooth volume brightness", run: () => Shell.open("controlcenter") },
        { id: "nc", title: "Notification Center", sub: "Calendar and notifications", icon: "notifications", color: "#ff453a", keys: ["Super", "N"], kw: "calendar", run: () => Shell.open("notifications") },
        { id: "calc", title: "Calculator", sub: "Type any expression, e.g. 2^10 or sqrt(2)", icon: "calculate", color: "#ff9f0a", keys: ["Super", "C"], kw: "math", query: "=" },
        { id: "shot-region", title: "Screenshot Region", sub: "Select an area, copy to clipboard", icon: "screenshot_region", color: "#30d158", keys: ["Super", "⇧", "S"], kw: "capture screen", run: () => Shell.run("sleep 0.3; hyprshot -m region") },
        { id: "shot-window", title: "Screenshot Window", sub: "Capture a window", icon: "screenshot_frame", color: "#30d158", kw: "capture", run: () => Shell.run("sleep 0.3; hyprshot -m window") },
        { id: "shot-screen", title: "Screenshot Screen", sub: "Capture the focused monitor", icon: "screenshot_monitor", color: "#30d158", kw: "capture", run: () => Shell.run("sleep 0.3; hyprshot -m output -m active") },
        { id: "picker", title: "Color Picker", sub: "Pick a colour, copy hex", icon: "colorize", color: "#ff375f", keys: ["Super", "`"], kw: "eyedropper hex", run: () => Shell.run("sleep 0.3; hyprpicker -a") },
        { id: "terminal", title: "New Terminal", sub: Config.terminal, icon: "terminal", color: "#1c1c1e", keys: ["Super", "Space"], kw: "shell console", run: () => Shell.run(Config.terminal) },
        { id: "files", title: "Home Folder", sub: "Open in " + Config.fileManager, icon: "folder", color: "#0a84ff", keys: ["Super", "E"], kw: "files finder", run: () => Shell.run(Config.fileManager) },
        { id: "about", title: "About This Computer", sub: "System info with a spinning pen", icon: "info", color: "#0a84ff", kw: "neofetch fastfetch system info specs", run: () => Shell.about() },
        { id: "btop", title: "Activity Monitor", sub: "btop in a terminal", icon: "monitoring", color: "#30d158", kw: "task manager processes cpu", run: () => Shell.run(Config.terminal + " -e btop") },
        { id: "trash", title: "Empty Trash", sub: "Permanently erase items in the Trash", icon: "delete_forever", color: "#8e8e93", kw: "bin", run: () => Shell.ask({ title: "Are you sure you want to permanently erase the items in the Trash?", body: "You can’t undo this action.", icon: "delete_forever", confirm: "Empty Trash", destructive: true, action: () => Shell.run("gio trash --empty") }) },
        { id: "dock", title: "Toggle Dock Auto-hide", sub: () => "Currently " + Config.dockAutohide, icon: "dock_to_bottom", color: "#636366", kw: "dock hide", run: () => Config.dockAutohide = Config.dockAutohide === "smart" ? "always" : Config.dockAutohide === "always" ? "never" : "smart", stay: true },
        { id: "reload", title: "Reload Shell", sub: "Restart Quickshell UI", icon: "refresh", color: "#636366", kw: "quickshell restart", run: () => Quickshell.reload(true) },
        { id: "lock", title: "Lock Screen", icon: "lock", color: "#1c1c1e", keys: ["Super", "L"], kw: "hyprlock", run: () => Shell.lock() },
        { id: "sleep", title: "Sleep", icon: "bedtime", color: "#5e5ce6", kw: "suspend", run: () => Shell.sleep() },
        { id: "restart", title: "Restart…", icon: "restart_alt", color: "#ff9f0a", kw: "reboot", run: () => Shell.askRestart() },
        { id: "shutdown", title: "Shut Down…", icon: "power_settings_new", color: "#ff453a", kw: "poweroff off", run: () => Shell.askShutdown() },
        { id: "logout", title: "Log Out…", icon: "logout", color: "#ff453a", keys: ["Super", "⇧", "L"], kw: "exit hyprland session", run: () => Shell.askLogout() }
    ]
    function subOf(c) { return typeof c.sub === "function" ? c.sub() : (c.sub || ""); }
}
