import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Raycast-style launcher (Super+R).
// Views: root · windows · wallpapers · shortcuts (+ file search via "/")
// Prefixes: ">" shell command · "?" web search · "/" files · "=" calculator
PopupLayer {
    id: lnc
    ns: "mac-launcher"
    persistent: true
    panelItem: win
    readonly property string sname: screen ? screen.name : ""
    open: Shell.isOpen("launcher", sname)
    openDuration: 130
    closeDuration: 100
    onDismissed: Shell.close()

    property string view: "root"
    property string query: ""
    property int sel: 0
    property bool actionsOpen: false
    property int actSel: 0
    property string toast: ""

    readonly property var viewInfo: ({
        root: { title: "Search", icon: "search", color: "#8e8e93", ph: "Search for apps and commands…" },
        windows: { title: "Windows", icon: "select_window", color: "#0a84ff", ph: "Search open windows…" },
        wallpapers: { title: "Wallpapers", icon: "wallpaper", color: "#5e5ce6", ph: "Filter wallpapers…" },
        shortcuts: { title: "Shortcuts", icon: "keyboard", color: "#8e8e93", ph: "Search keyboard shortcuts…" }
    })

    function reset() {
        view = Shell.launcherView === "calculator" ? "root" : Shell.launcherView;
        input.text = Shell.launcherView === "calculator" ? "=" : "";
        query = input.text;
        sel = 0; actionsOpen = false; toast = "";
        quick = view === "windows" && Shell.launcherQuick;
        Shell.launcherQuick = false;
        // Start on the previous window (index 0 is the focused one), like Cmd+Tab.
        quickInit = quick;
        applyQuickStart();
        if (view === "wallpapers") Wallpaper.refresh();
        if (view === "shortcuts") Keybinds.refresh();
        input.forceActiveFocus();
    }
    onOpenChanged: { altHeld = false; if (open) { Hyprland.refreshToplevels(); reset(); } }
    Connections { target: Shell; function onLauncherRequestChanged() { if (lnc.open) lnc.reset(); } }

    function go(v) {
        view = v; input.text = ""; query = ""; sel = 0; actionsOpen = false;
        if (v === "wallpapers") Wallpaper.refresh();
        if (v === "shortcuts") Keybinds.refresh();
    }
    function back() {
        if (actionsOpen) { actionsOpen = false; return; }
        if (input.text !== "") { input.text = ""; return; }
        if (view !== "root") { go("root"); return; }
        Shell.close();
    }
    function done() { Shell.close(); }
    function flash(msg) { toast = msg; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 1600; onTriggered: lnc.toast = "" }

    // ---- File search (prefix "/") ------------------------------------------
    property var fileResults: []
    readonly property string fileQuery: view === "root" && query.startsWith("/") ? query.slice(1).trim() : ""
    onFileQueryChanged: { fileResults = []; if (fileQuery.length >= 2) fileTimer.restart(); }
    Timer { id: fileTimer; interval: 160; onTriggered: { fd.running = false; fd.running = true; } }
    Process {
        id: fd
        command: ["fd", "--max-results", "50", "--ignore-case", "--hidden", "--exclude", ".git", "--exclude", ".cache", "--exclude", "node_modules", "--", lnc.fileQuery, Quickshell.env("HOME")]
        stdout: StdioCollector {
            onStreamFinished: lnc.fileResults = text.split("\n").filter(s => s).slice(0, 50)
        }
    }

    // ---- Result building ----------------------------------------------------
    function appItem(a, section) {
        const running = Windows.running(a.startupClass || a.id) || Windows.running(a.id);
        return { section: section, title: a.name, sub: a.genericName || a.comment || "", path: Apps.icon(a), accessory: running ? "Running" : "Application",
                 get actions() { return lnc.appActions(a, running); } };
    }
    function appActions(a, running) {
        const pinned = Config.isPinned(a.id);
        const acts = [
            { title: running ? "Switch to " + a.name : "Open", icon: "open_in_new", keys: ["↵"], fn: () => { lnc.done(); Shell.later(() => { if (!running || !Windows.activateApp(a.startupClass || a.id)) Apps.launch(a); }); } },
            { title: "Open New Window", icon: "add", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Apps.launch(a); lnc.done(); } }
        ];
        for (const act of a.actions) {
            const aa = act;
            acts.push({ title: aa.name, icon: "subdirectory_arrow_right", fn: () => { Apps.launchAction(a, aa); lnc.done(); } });
        }
        acts.push({ title: pinned ? "Remove from Dock" : "Keep in Dock", icon: "keep", keys: ["Ctrl", "P"], hot: "ctrl+p", fn: () => { Config.togglePin(a.id); lnc.flash(pinned ? "Removed from Dock" : "Added to Dock"); } });
        if (running) acts.push({ title: "Quit " + a.name, icon: "cancel", keys: ["Ctrl", "Q"], hot: "ctrl+q", destructive: true, fn: () => { Windows.quitApp(a.startupClass || a.id); Windows.quitApp(a.id); lnc.flash("Quit " + a.name); } });
        acts.push({ title: "Copy Name", icon: "content_copy", keys: ["Ctrl", "⇧", "C"], hot: "ctrl+shift+c", fn: () => { Quickshell.clipboardText = a.name; lnc.flash("Copied"); } });
        acts.push({ title: "Reset Ranking", icon: "restart_alt", fn: () => { Apps.forget("app:" + a.id); lnc.flash("Ranking reset"); } });
        return acts;
    }
    function cmdItem(c, section) {
        const acts = [{ title: c.view ? "Open " + c.title : c.title, icon: "play_arrow", keys: ["↵"], fn: () => {
            Apps.record("cmd:" + c.id);
            if (c.view) lnc.go(c.view);
            else if (c.query !== undefined) { input.text = c.query; }
            else { c.run(); if (!c.stay) lnc.done(); else lnc.flash(c.title); }
        } }];
        return { section: section, title: c.title, sub: Commands.subOf(c), sym: c.icon, tint: c.color, keys: c.keys, accessory: c.keys ? "" : "Command", actions: acts };
    }
    function winItem(t, section) {
        const appId = Windows.appIdOf(t);
        const ws = t.workspace ? t.workspace.name : "?";
        return {
            section: section, title: t.title || Apps.nameForAppId(appId), sub: Apps.nameForAppId(appId), path: Apps.iconForAppId(appId),
            accessory: "Workspace " + ws,
            actions: [
                { title: "Switch to Window", icon: "open_in_new", keys: ["↵"], fn: () => { lnc.done(); Shell.later(() => Windows.focus(t)); } },
                { title: "Move to This Workspace", icon: "move_down", keys: ["Ctrl", "M"], hot: "ctrl+m", fn: () => { lnc.done(); Shell.later(() => { Windows.moveHere(t); Windows.focus(t); }); } },
                { title: "Close Window", icon: "close", keys: ["Ctrl", "W"], hot: "ctrl+w", destructive: true, fn: () => { Windows.close(t); lnc.flash("Closed"); refreshTimer.restart(); } },
                { title: "Copy Title", icon: "content_copy", fn: () => { Quickshell.clipboardText = t.title; lnc.flash("Copied"); } }
            ]
        };
    }
    Timer { id: refreshTimer; interval: 300; onTriggered: Hyprland.refreshToplevels() }

    function fileItem(p) {
        const dir = p.endsWith("/");
        const clean = dir ? p.slice(0, -1) : p;
        const name = clean.slice(clean.lastIndexOf("/") + 1);
        const parent = clean.slice(0, clean.lastIndexOf("/")).replace(Quickshell.env("HOME"), "~");
        return {
            section: "Files", title: name, sub: parent, path: Quickshell.iconPath(dir ? "folder" : "text-x-generic"), accessory: dir ? "Folder" : "",
            actions: [
                { title: "Open", icon: "open_in_new", keys: ["↵"], fn: () => { Quickshell.execDetached(["xdg-open", clean]); lnc.done(); } },
                { title: "Show in Folder", icon: "folder_open", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Quickshell.execDetached([Config.fileManager, dir ? clean : clean.slice(0, clean.lastIndexOf("/"))]); lnc.done(); } },
                { title: "Open Terminal Here", icon: "terminal", keys: ["Ctrl", "T"], hot: "ctrl+t", fn: () => { Quickshell.execDetached([Config.terminal, "--directory", dir ? clean : clean.slice(0, clean.lastIndexOf("/"))]); lnc.done(); } },
                { title: "Copy Path", icon: "content_copy", keys: ["Ctrl", "⇧", "C"], hot: "ctrl+shift+c", fn: () => { Quickshell.clipboardText = clean; lnc.flash("Path copied"); } }
            ]
        };
    }

    readonly property var items: {
        if (!open) return [];
        const q = query.trim();
        const ql = q.toLowerCase();
        const out = [];
        if (view === "windows") {
            let wins = Array.from(Windows.all);
            wins.sort((a, b) => ((a.lastIpcObject || {}).focusHistoryID ?? 99) - ((b.lastIpcObject || {}).focusHistoryID ?? 99));
            if (ql) wins = wins.filter(t => Apps.fuzzy(t.title + " " + Apps.nameForAppId(Windows.appIdOf(t)), ql) > 0);
            for (const t of wins) out.push(winItem(t, "Open Windows"));
            return out;
        }
        if (view === "shortcuts") {
            for (const k of Keybinds.all) {
                if (ql && Apps.fuzzy(k.text + " " + k.category + " " + k.keys.join(" "), ql) <= 0) continue;
                out.push({ section: k.category, title: k.text, kbd: k.keys, actions: [] });
            }
            const order = ["Shell", "Launcher", "Clipboard", "Windows", "Workspaces", "Focus", "Dock", "Menu Bar", "Control Center", "Notifications", "Session", "Tools", "Apps", "Monitors"];
            const rank = c => { const i = order.indexOf(c); return i < 0 ? 99 : i; };
            return out.map((x, i) => ({ x: x, i: i })).sort((a, b) => (rank(a.x.section) - rank(b.x.section)) || a.x.section.localeCompare(b.x.section) || (a.i - b.i)).map(o => o.x);
        }
        if (view === "wallpapers") return [];

        // ---- root ----
        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            if (cmd) out.push({ section: "Shell", title: cmd, sub: "Run in " + Config.terminal, sym: "terminal", tint: "#1c1c1e", accessory: "Command",
                actions: [
                    { title: "Run in Terminal", icon: "terminal", keys: ["↵"], fn: () => { lnc.runInTerminal(cmd); lnc.done(); } },
                    { title: "Run in Background", icon: "play_arrow", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Shell.run(cmd); lnc.done(); } }
                ] });
            return out;
        }
        if (q.startsWith("?")) {
            const s = q.slice(1).trim();
            if (s) out.push(webItem(s));
            return out;
        }
        if (q.startsWith("/")) {
            for (const f of fileResults) out.push(fileItem(f));
            if (!fileResults.length) out.push({ section: "Files", title: fileQuery.length < 2 ? "Type at least 2 characters" : fd.running ? "Searching…" : "No files found", sym: "search", tint: "#8e8e93", actions: [] });
            return out;
        }

        const calc = Calc.tryEval(q);
        if (calc.ok) {
            out.push({ section: "Calculator", calc: true, expr: q.replace(/^=/, ""), result: calc.text, title: calc.text,
                actions: [
                    { title: "Copy Answer", icon: "content_copy", keys: ["↵"], fn: () => { Quickshell.clipboardText = Calc.plain(calc.value); lnc.done(); } },
                    { title: "Paste Answer", icon: "content_paste_go", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Quickshell.clipboardText = Calc.plain(calc.value); lnc.done(); Clip.sendPaste(); } },
                    { title: "Copy Expression", icon: "functions", keys: ["Ctrl", "⇧", "C"], hot: "ctrl+shift+c", fn: () => { Quickshell.clipboardText = q.replace(/^=/, "") + " = " + Calc.plain(calc.value); lnc.done(); } }
                ] });
        }
        if (q === "=" ) {
            out.push({ section: "Calculator", title: "Type an expression", sub: "e.g. 12*(3+4), sqrt(2), 2^32, 0xff, 5!, sin(pi/4)", sym: "calculate", tint: "#ff9f0a", actions: [] });
            return out;
        }

        if (!ql) {
            const recents = Apps.suggestions(6);
            for (const a of recents) out.push(appItem(a, "Suggestions"));
            const cmds = Commands.list.map((c, i) => ({ c: c, i: i, f: Apps.frecency("cmd:" + c.id) }))
                .sort((a, b) => (b.f - a.f) || (a.i - b.i)).map(x => x.c);
            for (const c of cmds) out.push(cmdItem(c, "Commands"));
            for (const a of Apps.apps) if (recents.indexOf(a) < 0) out.push(appItem(a, "Applications"));
            return out;
        }

        // Scored mix of apps / commands / windows
        const mixed = [];
        for (const a of Apps.search(ql, 12)) mixed.push({ s: Apps.scoreApp(a, ql) + Apps.frecency("app:" + a.id) * 6 + 2, it: appItem(a, "Results") });
        for (const c of Commands.list) {
            const s = Math.max(Apps.fuzzy(c.title, ql), Apps.fuzzy(c.kw || "", ql) * 0.7);
            if (s > 0) mixed.push({ s: s + Apps.frecency("cmd:" + c.id) * 6, it: cmdItem(c, "Results") });
        }
        mixed.sort((a, b) => b.s - a.s);
        for (const m of mixed.slice(0, 14)) out.push(m.it);
        const wins = Windows.all.filter(t => Apps.fuzzy(t.title || "", ql) > 20).slice(0, 4);
        for (const t of wins) out.push(winItem(t, "Windows"));

        // Fallbacks
        out.push(webItem(q, "Use “" + q + "” with…"));
        out.push({ section: "Use “" + q + "” with…", title: "Search Files", sub: "fd in ~", sym: "folder_open", tint: "#0a84ff", accessory: "/",
            actions: [{ title: "Search Files", icon: "search", keys: ["↵"], fn: () => { input.text = "/" + q; } }] });
        out.push({ section: "Use “" + q + "” with…", title: "Run in Terminal", sub: q, sym: "terminal", tint: "#1c1c1e", accessory: ">",
            actions: [{ title: "Run in Terminal", icon: "terminal", keys: ["↵"], fn: () => { lnc.runInTerminal(q); lnc.done(); } },
                      { title: "Run in Background", icon: "play_arrow", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Shell.run(q); lnc.done(); } }] });
        return out;
    }
    // Runs in the user's login shell inside the terminal; the window stays
    // open afterwards so output (and errors) can be read.
    function runInTerminal(cmd) {
        const sh = Quickshell.env("SHELL") || "bash";
        Quickshell.execDetached([Config.terminal, "--hold", "-e", sh, "-c", cmd]);
    }
    function webItem(s, section) {
        const url = "https://www.google.com/search?q=" + encodeURIComponent(s);
        return { section: section || "Web", title: "Search Google for “" + s + "”", sym: "travel_explore", tint: "#0a84ff", accessory: "?",
            actions: [
                { title: "Open in Browser", icon: "open_in_new", keys: ["↵"], fn: () => { Quickshell.execDetached(["xdg-open", url]); lnc.done(); } },
                { title: "Search DuckDuckGo", icon: "travel_explore", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(s)]); lnc.done(); } }
            ] };
    }

    readonly property var wallItems: {
        if (!open || view !== "wallpapers") return [];
        const ql = query.trim().toLowerCase();
        return Wallpaper.list.filter(p => !ql || p.toLowerCase().indexOf(ql) >= 0);
    }
    readonly property int count: view === "wallpapers" ? wallItems.length : items.length
    readonly property var current: view === "wallpapers" ? null : items[sel]
    readonly property var currentActions: {
        if (view === "wallpapers") {
            const p = wallItems[sel];
            if (!p) return [];
            return [
                { title: "Set Wallpaper", icon: "wallpaper", keys: ["↵"], fn: () => { Wallpaper.set(p); lnc.flash("Wallpaper set · theme updated"); } },
                { title: "Set and Close", icon: "done", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Wallpaper.set(p); lnc.done(); } },
                { title: "Random Wallpaper", icon: "shuffle", keys: ["Ctrl", "R"], hot: "ctrl+r", fn: () => Wallpaper.random() },
                { title: "Open Wallpaper Folder", icon: "folder_open", fn: () => { Quickshell.execDetached([Config.fileManager, Config.wallpaperDir]); lnc.done(); } },
                { title: "Copy Path", icon: "content_copy", keys: ["Ctrl", "⇧", "C"], hot: "ctrl+shift+c", fn: () => { Quickshell.clipboardText = p; lnc.flash("Path copied"); } }
            ];
        }
        return current ? current.actions : [];
    }
    onQueryChanged: { sel = 0; actionsOpen = false; }
    onViewChanged: sel = 0

    function run(i) {
        if (view !== "wallpapers") sel = i;
        const acts = currentActions;
        if (acts.length) acts[0].fn();
    }
    function hotString(e) {
        let s = "";
        if (e.modifiers & Qt.ControlModifier) s += "ctrl+";
        if (e.modifiers & Qt.ShiftModifier) s += "shift+";
        if (e.modifiers & Qt.AltModifier) s += "alt+";
        const k = e.key === Qt.Key_Return || e.key === Qt.Key_Enter ? "return" : e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 ? e.text.toLowerCase() : String.fromCharCode(e.key).toLowerCase();
        return s + k;
    }
    function moveSel(d, wrap) {
        if (wrap && !actionsOpen && view !== "wallpapers" && count > 0) {
            sel = ((sel + d) % count + count) % count;
            list.positionViewAtIndex(sel, ListView.Contain);
            return;
        }
        if (actionsOpen) { actSel = Math.max(0, Math.min(currentActions.length - 1, actSel + d)); return; }
        if (view === "wallpapers") { sel = Math.max(0, Math.min(count - 1, sel + d)); grid.positionViewAtIndex(sel, GridView.Contain); return; }
        let i = sel + d;
        i = Math.max(0, Math.min(count - 1, i));
        sel = i;
        list.positionViewAtIndex(sel, ListView.Contain);
    }

    // ================================ UI ===================================
    Glass {
        id: win
        width: 760
        height: 476
        radius: 16
        tint: Theme.glassThick
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.18)
        opacity: lnc.t
        scale: 0.98 + 0.02 * lnc.t

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---- Search bar ------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 10

                Hoverable {
                    visible: lnc.view !== "root"
                    implicitWidth: 28; implicitHeight: 28; radius: 8
                    Sym { anchors.centerIn: parent; name: "arrow_back"; size: 18; color: Theme.text2 }
                    onClicked: lnc.go("root")
                }
                Rectangle {
                    visible: lnc.view !== "root"
                    implicitHeight: 26
                    implicitWidth: crumb.implicitWidth + 16
                    radius: 7
                    color: Theme.field
                    Row {
                        id: crumb
                        anchors.centerIn: parent
                        spacing: 5
                        Sym { anchors.verticalCenter: parent.verticalCenter; name: lnc.viewInfo[lnc.view].icon; size: 15; filled: true; color: lnc.viewInfo[lnc.view].color }
                        T { anchors.verticalCenter: parent.verticalCenter; text: lnc.viewInfo[lnc.view].title; font.pixelSize: 13; font.weight: Font.Medium }
                    }
                }
                Sym { visible: lnc.view === "root"; name: "search"; size: 22; color: Theme.text2 }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    font.family: Config.fontFamily
                    font.pixelSize: 18
                    color: Theme.text
                    selectionColor: Theme.selection
                    selectedTextColor: "white"
                    clip: true
                    focus: true
                    onTextChanged: { lnc.query = text; if (text !== "") lnc.quick = false; }
                    T {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: lnc.viewInfo[lnc.view].ph
                        font.pixelSize: 18
                        color: Theme.text3
                    }
                    Keys.onReleased: e => {
                        if (e.key === Qt.Key_Alt) lnc.altHeld = false;
                        if (lnc.quick && (e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L || e.key === Qt.Key_Super_R)) {
                            lnc.quick = false;
                            lnc.run(lnc.sel);
                        }
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Alt) { lnc.altHeld = true; return; }
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        const alt = e.modifiers & Qt.AltModifier;
                        const wallCols = 4;
                        if (e.key === Qt.Key_Escape) { lnc.back(); e.accepted = true; return; }
                        if (e.key === Qt.Key_K && ctrl) { lnc.actionsOpen = !lnc.actionsOpen; lnc.actSel = 0; e.accepted = true; return; }
                        if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_N)) { lnc.moveSel(lnc.view === "wallpapers" && !lnc.actionsOpen ? wallCols : 1); e.accepted = true; return; }
                        const ctrlPFree = !lnc.currentActions.some(x => x.hot === "ctrl+p");
                        if (e.key === Qt.Key_Up || (ctrl && e.key === Qt.Key_P && ctrlPFree)) { lnc.moveSel(lnc.view === "wallpapers" && !lnc.actionsOpen ? -wallCols : -1); e.accepted = true; return; }
                        if (lnc.view === "wallpapers" && !lnc.actionsOpen && (e.key === Qt.Key_Left || e.key === Qt.Key_Right) && input.text === "") { lnc.moveSel(e.key === Qt.Key_Left ? -1 : 1); e.accepted = true; return; }
                        if (e.key === Qt.Key_PageDown) { lnc.moveSel(8); e.accepted = true; return; }
                        if (e.key === Qt.Key_PageUp) { lnc.moveSel(-8); e.accepted = true; return; }
                        if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) { lnc.moveSel(-1, lnc.view === "windows"); e.accepted = true; return; }
                        if (e.key === Qt.Key_Tab && lnc.view !== "wallpapers") { lnc.moveSel(1, lnc.view === "windows"); e.accepted = true; return; }
                        if (e.key === Qt.Key_Backspace && input.text === "" && lnc.view !== "root") { lnc.go("root"); e.accepted = true; return; }
                        if (alt && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { const i = e.key - Qt.Key_1; if (i < lnc.count) lnc.run(i); e.accepted = true; return; }
                        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            if (lnc.actionsOpen) { const a = lnc.currentActions[lnc.actSel]; lnc.actionsOpen = false; if (a) a.fn(); e.accepted = true; return; }
                            if (!ctrl) { lnc.run(lnc.sel); e.accepted = true; return; }
                        }
                        // Action hotkeys (ctrl+… / ctrl+return)
                        if (ctrl) {
                            const h = lnc.hotString(e);
                            const a = lnc.currentActions.find(x => x.hot === h);
                            if (a) { lnc.actionsOpen = false; a.fn(); e.accepted = true; return; }
                        }
                    }
                }
                T {
                    visible: lnc.view === "root" && input.text === ""
                    text: "Super R"
                    font.pixelSize: 11
                    color: Theme.text3
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

            // ---- Result list -------------------------------------------------
            ListView {
                id: list
                visible: lnc.view !== "wallpapers"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                clip: true
                model: lnc.view !== "wallpapers" ? lnc.items : []
                currentIndex: lnc.sel
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                reuseItems: true
                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index
                    readonly property bool showHeader: index === 0 || lnc.items[index - 1].section !== modelData.section
                    readonly property bool isSel: index === lnc.sel
                    width: list.width
                    height: (showHeader ? 30 : 0) + (modelData.calc ? 96 : 44)

                    T {
                        visible: rowItem.showHeader
                        x: 22; y: 10
                        text: rowItem.modelData.section
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Theme.text3
                    }

                    Rectangle {
                        id: rowBg
                        x: 8
                        width: parent.width - 16
                        y: rowItem.showHeader ? 30 : 0
                        height: rowItem.modelData.calc ? 96 : 44
                        radius: 10
                        color: rowItem.isSel ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.075))
                                             : rma.containsMouse ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.035)) : "transparent"

                        // Normal row
                        RowLayout {
                            visible: !rowItem.modelData.calc
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 12
                            ItemIcon {
                                visible: !rowItem.modelData.kbd
                                path: rowItem.modelData.path || ""
                                sym: rowItem.modelData.sym || ""
                                tint: rowItem.modelData.tint || "#8e8e93"
                                size: 26
                            }
                            T {
                                text: rowItem.modelData.title
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                Layout.maximumWidth: rowBg.width * 0.55
                            }
                            T {
                                Layout.fillWidth: true
                                text: rowItem.modelData.sub || ""
                                font.pixelSize: 13
                                color: Theme.text2
                            }
                            Kbd { visible: !!rowItem.modelData.kbd || !!rowItem.modelData.keys; opacity: rowItem.modelData.kbd || rowItem.isSel ? 1 : 0.6; keys: rowItem.modelData.kbd || rowItem.modelData.keys || [] }
                            T {
                                visible: !!rowItem.modelData.accessory && !rowItem.modelData.kbd
                                text: rowItem.modelData.accessory || ""
                                font.pixelSize: 12
                                color: rowItem.modelData.accessory === "Running" ? Theme.systemGreen : Theme.text3
                            }
                            T {
                                visible: rowItem.index < 9 && lnc.altHeld
                                text: "Alt " + (rowItem.index + 1)
                                font.pixelSize: 11
                                color: Theme.text3
                            }
                        }

                        // Calculator card
                        RowLayout {
                            visible: !!rowItem.modelData.calc
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 2
                                T { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: rowBg.width * 0.42; text: rowItem.modelData.expr || ""; font.pixelSize: 24; font.weight: Font.Medium }
                                T { Layout.alignment: Qt.AlignHCenter; text: "Expression"; font.pixelSize: 11; color: Theme.text3 }
                            }
                            Sym { name: "arrow_forward"; size: 22; color: Theme.text3 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 2
                                T { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: rowBg.width * 0.42; text: rowItem.modelData.result || ""; font.pixelSize: 24; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                                T { Layout.alignment: Qt.AlignHCenter; text: "Result · ↵ copies"; font.pixelSize: 11; color: Theme.text3 }
                            }
                        }

                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: m => {
                                lnc.sel = rowItem.index;
                                if (m.button === Qt.RightButton) { lnc.actionsOpen = true; lnc.actSel = 0; }
                                else lnc.run(rowItem.index);
                                input.forceActiveFocus();
                            }
                        }
                    }
                }

                // Empty state
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: lnc.count === 0
                    spacing: 6
                    Sym { Layout.alignment: Qt.AlignHCenter; name: lnc.view === "windows" ? "select_window" : "search_off"; size: 36; color: Theme.text3 }
                    T { Layout.alignment: Qt.AlignHCenter; text: lnc.view === "windows" ? "No open windows" : "No results"; font.pixelSize: 14; color: Theme.text2 }
                }
            }

            // ---- Wallpaper grid ---------------------------------------------
            GridView {
                id: grid
                visible: lnc.view === "wallpapers"
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 10
                clip: true
                cellWidth: Math.floor(width / 4)
                cellHeight: Math.floor(cellWidth * 0.62) + 26
                model: lnc.view === "wallpapers" ? lnc.wallItems : []
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: wcell
                    required property string modelData
                    required property int index
                    readonly property bool isSel: index === lnc.sel
                    readonly property bool isCurrent: modelData === Wallpaper.current
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        id: frame
                        x: 5; y: 5
                        width: parent.width - 10
                        height: Math.floor((parent.width - 10) * 0.62)
                        radius: 10
                        color: "transparent"
                        border.width: wcell.isSel ? 3 : 0
                        border.color: Theme.accent
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: wcell.isSel ? 4 : 0
                            radius: 8
                            color: Theme.field
                            Image {
                                anchors.fill: parent
                                source: "file://" + wcell.modelData
                                sourceSize.width: 360
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                        }
                        Rectangle {
                            visible: wcell.isCurrent
                            anchors.right: parent.right; anchors.bottom: parent.bottom
                            anchors.margins: 8
                            width: 22; height: 22; radius: 11
                            color: Theme.accent
                            Sym { anchors.centerIn: parent; name: "check"; size: 15; weight: 700; color: "white" }
                        }
                    }
                    T {
                        anchors.top: frame.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                        text: wcell.modelData.slice(wcell.modelData.lastIndexOf("/") + 1).replace(/\.\w+$/, "")
                        font.pixelSize: 11
                        color: wcell.isSel ? Theme.text : Theme.text2
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { lnc.sel = wcell.index; Wallpaper.set(wcell.modelData); input.forceActiveFocus(); }
                        onDoubleClicked: { Wallpaper.set(wcell.modelData); lnc.done(); }
                    }
                }
            }

            // ---- Footer ---------------------------------------------------------
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                spacing: 10
                Sym {
                    name: lnc.toast !== "" ? "check_circle" : lnc.viewInfo[lnc.view].icon
                    size: 16; filled: true
                    color: lnc.toast !== "" ? Theme.systemGreen : Theme.text2
                }
                T {
                    Layout.fillWidth: true
                    text: lnc.toast !== "" ? lnc.toast
                        : lnc.view === "root" ? "Tips: > run · ? web · / files · = maths"
                        : lnc.view === "wallpapers" ? "Theme and accent follow the wallpaper"
                        : lnc.view === "shortcuts" ? Keybinds.all.length + " shortcuts"
                        : lnc.quick ? "Release Super to switch · Tab / ⇧Tab to move" : lnc.count + " windows"
                    font.pixelSize: 12
                    color: Theme.text2
                }
                Hint {
                    visible: lnc.currentActions.length > 0
                    label: lnc.currentActions.length ? lnc.currentActions[0].title : ""
                    keys: ["↵"]
                    strong: true
                }
                Rectangle { visible: lnc.currentActions.length > 1; width: 1; height: 16; color: Theme.separator }
                Hint {
                    visible: lnc.currentActions.length > 1
                    label: "Actions"
                    keys: ["Ctrl", "K"]
                }
            }
        }

        // ---- Action panel (Ctrl+K) -----------------------------------------
        Glass {
            id: actions
            visible: lnc.actionsOpen && lnc.currentActions.length > 0
            radius: 12
            tint: Theme.glassThick
            width: 300
            height: Math.min(actCol.implicitHeight + 12, win.height - 110)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            anchors.bottomMargin: 48
            ColumnLayout {
                id: actCol
                x: 6; y: 6
                width: parent.width - 12
                spacing: 0
                T {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.preferredHeight: 24
                    text: lnc.current ? lnc.current.title : "Actions"
                    font.pixelSize: 11; font.weight: Font.DemiBold
                    color: Theme.text3
                }
                Repeater {
                    model: lnc.actionsOpen ? lnc.currentActions : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 7
                        color: index === lnc.actSel ? (modelData.destructive ? Theme.systemRed : Theme.accent) : am.containsMouse ? Theme.hover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Sym { name: modelData.icon || "bolt"; size: 16; color: index === lnc.actSel ? "white" : modelData.destructive ? Theme.systemRed : Theme.text2 }
                            T { Layout.fillWidth: true; text: modelData.title; font.pixelSize: 13; color: index === lnc.actSel ? "white" : Theme.text }
                            Kbd { visible: !!modelData.keys; keys: modelData.keys || []; textColor: index === lnc.actSel ? "white" : Theme.text2 }
                        }
                        MouseArea {
                            id: am
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: lnc.actSel = index
                            onClicked: { lnc.actionsOpen = false; modelData.fn(); input.forceActiveFocus(); }
                        }
                    }
                }
            }
        }
    }

    property bool altHeld: false
    property bool quick: false               // release Super to switch (Super+Tab)
    property bool quickInit: false           // start position still to be applied
    // The window list refreshes as the switcher opens, so place the initial
    // selection once it has more than one entry.
    function applyQuickStart() {
        if (!quickInit || view !== "windows" || count < 2) return;
        quickInit = false;
        sel = Shell.launcherQuickDir > 0 ? 1 : count - 1;
        list.positionViewAtIndex(sel, ListView.Contain);
    }
    onCountChanged: applyQuickStart()
    Connections {
        target: Shell
        function onSwitcherStep(dir) { if (lnc.open) lnc.moveSel(dir, true); }
        function onActivateSelection() { if (lnc.open) lnc.run(lnc.sel); }
    }
}
