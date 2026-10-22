import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.widgets

// macOS dock: Apps (launcher) · pinned apps · running apps · Trash.
// Click: open / focus / cycle windows · Middle-click: new window · Right-click: menu
// Auto-hide ("smart"): hidden while the workspace has windows, reveal at bottom edge.
PanelWindow {
    id: dock
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 150
    color: "transparent"
    exclusiveZone: Config.dockAutohide === "never" ? baseSize + pad * 2 + bottomGap + 4 : 0
    WlrLayershell.namespace: "mac-dock"
    WlrLayershell.layer: WlrLayer.Top

    readonly property string sname: screen ? screen.name : ""
    visible: !Focus.active
    Component.onCompleted: Shell.registerDock(sname, dock)
    onSnameChanged: Shell.registerDock(sname, dock)
    readonly property int baseSize: 50
    readonly property int maxSize: Config.dockMagnify ? 74 : baseSize
    readonly property int pad: 7
    readonly property int gap: 6
    readonly property int bottomGap: 6
    readonly property int sepWidth: 13

    // ---- Model -------------------------------------------------------------
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var activeWs: monitor ? monitor.activeWorkspace : null
    readonly property string activeAppId: Windows.appIdOf(Hyprland.activeToplevel)

    readonly property var items: {
        const pinned = Array.from(Config.dockPinned);
        const runIds = Windows.runningAppIds();
        // desktop id -> appIds that belong to it
        const byEntry = {};
        const loose = [];
        for (const appId of runIds) {
            const e = Apps.forAppId(appId);
            const key = e ? e.id : appId;
            if (pinned.indexOf(key) >= 0) (byEntry[key] = byEntry[key] || []).push(appId);
            else if (!loose.some(l => l.key === key)) loose.push({ key: key, entry: e, appIds: [appId] });
            else loose.find(l => l.key === key).appIds.push(appId);
        }
        const out = [{ type: "launcher", key: "__launcher" }];
        for (const id of pinned) {
            const e = Apps.byId(id);
            if (!e) continue;
            out.push({ type: "app", key: id, entry: e, appIds: byEntry[id] || [], pinned: true });
        }
        if (loose.length) {
            out.push({ type: "sep", key: "__sep1" });
            for (const l of loose) out.push({ type: "app", key: l.key, entry: l.entry, appIds: l.appIds, pinned: false });
        }
        out.push({ type: "sep", key: "__sep2" });
        out.push({ type: "trash", key: "__trash" });
        return out;
    }
    function widthOf(it) { return it.type === "sep" ? sepWidth : baseSize; }
    // Un-magnified centres relative to the dock centre (stable magnification maths).
    readonly property var baseCenters: {
        const ws = items.map(widthOf);
        const total = ws.reduce((a, b) => a + b, 0) + gap * (ws.length - 1);
        const out = [];
        let x = -total / 2;
        for (const w of ws) { out.push(x + w / 2); x += w + gap; }
        return out;
    }

    // ---- Hover / magnification -------------------------------------------
    property real mouseX: -1e6                 // relative to screen centre
    readonly property bool hovering: hoverArea.hovered
    // 0..1, eased so magnification grows/settles smoothly on hover in/out.
    property real magnify: hovering && !Shell.menuOpen ? 1 : 0
    Behavior on magnify { NumberAnimation { duration: dock.hovering ? 200 : 320; easing.type: Easing.OutCubic } }
    function sizeAt(i) {
        if (magnify <= 0.001 || items[i].type === "sep") return widthOf(items[i]);
        const d = mouseX - baseCenters[i];
        const sigma = baseSize * 1.25;
        return baseSize + (maxSize - baseSize) * magnify * Math.exp(-(d * d) / (2 * sigma * sigma));
    }

    // ---- Visibility -----------------------------------------------------
    readonly property bool wsBusy: activeWs ? activeWs.toplevels.values.length > 0 : false
    readonly property bool menuHere: Shell.menuOpen && Shell.menuScreen === sname && Shell.menuAbove
    property bool revealed: false
    readonly property bool fullscreenApp: activeWs ? activeWs.hasFullscreen : false
    readonly property bool shown: !fullscreenApp && (Config.dockAutohide === "never"
                                  || (Config.dockAutohide === "smart" && !wsBusy)
                                  || revealed || menuHere)
    onHoveringChanged: if (hovering) { hideTimer.stop(); revealed = true; } else hideTimer.restart()
    Timer { id: hideTimer; interval: 450; onTriggered: if (!dock.hovering) dock.revealed = false }

    property real slide: shown ? 0 : 1
    Behavior on slide {
        NumberAnimation {
            duration: dock.shown ? 460 : 320
            easing.type: dock.shown ? Easing.OutQuint : Easing.InOutCubic
        }
    }

    mask: Region { item: dock.shown ? hitArea : trigger }

    Item {
        id: trigger
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: bg.width
        height: 3
    }
    Item {
        id: hitArea
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: bg.width
        height: bg.height + dock.bottomGap + (dock.magnify > 0 ? dock.maxSize - dock.baseSize + 6 : 0)
    }

    // Parent of all dock content: receives hover even over the icons.
    // Input is limited to hitArea by the window mask.
    HoverHandler {
        id: hoverArea
        parent: dock.contentItem
        onPointChanged: dock.mouseX = point.position.x - dock.width / 2
    }
    MouseArea {
        anchors.fill: trigger
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: { dock.revealed = true; hideTimer.restart(); }
    }

    // ---- Trash state --------------------------------------------------------
    property bool trashFull: false
    Process {
        id: trashCheck
        command: ["bash", "-c", "[ -n \"$(ls -A ~/.local/share/Trash/files 2>/dev/null)\" ] && echo full || echo empty"]
        stdout: StdioCollector { onStreamFinished: dock.trashFull = text.trim() === "full" }
    }
    Timer { interval: 8000; running: dock.shown; repeat: true; triggeredOnStart: true; onTriggered: trashCheck.running = true }

    // ---- Visuals -------------------------------------------------------------
    Glass {
        id: bg
        radius: 24
        tint: Theme.glassDock
        shadowStrength: 0.7
        absorb: false
        height: dock.baseSize + dock.pad * 2
        width: row.width + dock.pad * 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.height - height - dock.bottomGap + dock.slide * (height + dock.bottomGap + 12)
        opacity: 1 - dock.slide * 0.6
    }
    // Hide delay after the pointer leaves (smart/always modes).

    Row {
        id: row
        anchors.horizontalCenter: bg.horizontalCenter
        anchors.bottom: bg.bottom
        anchors.bottomMargin: dock.pad
        spacing: dock.gap

        Repeater {
            model: dock.items
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property real size: dock.sizeAt(index)
                readonly property bool running: modelData.type === "app" && modelData.appIds.length > 0
                readonly property bool focused: running && modelData.appIds.indexOf(dock.activeAppId) >= 0
                readonly property string label: modelData.type === "launcher" ? "Apps"
                                              : modelData.type === "trash" ? "Trash"
                                              : modelData.entry ? modelData.entry.name : Apps.nameForAppId((modelData.appIds || [])[0])
                width: modelData.type === "sep" ? dock.sepWidth : size
                height: modelData.type === "sep" ? dock.baseSize : size
                anchors.bottom: parent.bottom

                property real bounce: 0

                Rectangle {
                    visible: cell.modelData.type === "sep"
                    anchors.centerIn: parent
                    width: 1; height: dock.baseSize - 12
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.18)
                }

                IconImage {
                    id: icon
                    visible: cell.modelData.type !== "sep"
                    width: cell.size; height: cell.size
                    y: -cell.bounce
                    implicitSize: dock.maxSize
                    mipmap: true
                    source: cell.modelData.type === "launcher" ? Quickshell.iconPath("view-app-grid", "applications-all")
                          : cell.modelData.type === "trash" ? Quickshell.iconPath(dock.trashFull ? "user-trash-full" : "user-trash")
                          : Apps.icon(cell.modelData.entry, (cell.modelData.appIds || [])[0])
                    scale: ma.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    // Dim when pressed, like macOS.
                    Rectangle { anchors.fill: parent; radius: width * 0.22; color: "black"; opacity: ma.pressed ? 0.25 : 0 }
                }

                // Running indicator
                Rectangle {
                    visible: cell.running
                    width: 4; height: 4; radius: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 1
                    color: Theme.dark ? Qt.rgba(1, 1, 1, cell.focused ? 0.95 : 0.6) : Qt.rgba(0, 0, 0, cell.focused ? 0.8 : 0.5)
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                // Tooltip
                Glass {
                    id: tip
                    visible: opacity > 0
                    opacity: ma.containsMouse && !Shell.menuOpen && cell.modelData.type !== "sep" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    radius: 8
                    tint: Theme.glassThick
                    shadowStrength: 0.5
                    absorb: false
                    width: tipText.implicitWidth + 20
                    height: 26
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -height - 14 - cell.bounce
                    T { id: tipText; anchors.centerIn: parent; text: cell.label; font.pixelSize: 12; font.weight: Font.Medium }
                }

                SequentialAnimation {
                    id: bounceAnim
                    loops: 2
                    NumberAnimation { target: cell; property: "bounce"; to: 18; duration: 260; easing.type: Easing.OutQuad }
                    NumberAnimation { target: cell; property: "bounce"; to: 0; duration: 300; easing.type: Easing.OutBounce }
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    enabled: cell.modelData.type !== "sep"
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: m => {
                        const it = cell.modelData;
                        if (m.button === Qt.RightButton) { dock.openMenu(cell, it); return; }
                        if (it.type === "launcher") { Shell.toggleLauncher("root"); return; }
                        if (it.type === "trash") { Shell.run(Config.fileManager + " trash:///"); return; }
                        if (m.button === Qt.MiddleButton || !cell.running) {
                            if (it.entry) { Apps.launch(it.entry); if (!cell.running) bounceAnim.restart(); }
                            return;
                        }
                        Windows.activateApp(it.appIds[0]);
                    }
                }
            }
        }
    }

    function openMenu(cell, it) {
        const p = cell.mapToItem(null, 0, 0);
        const overlayY = (screen ? screen.height : dock.height) - dock.height + bg.y - Config.barHeight - 6;
        let rows = [];
        if (it.type === "launcher") {
            rows = [
                { header: "Apps" },
                { text: "Open Launcher", icon: "search", shortcut: "Super R", action: () => Shell.toggleLauncher("root") },
                { text: "Clipboard History", icon: "content_paste", shortcut: "Super V", action: () => Shell.open("clipboard") },
                { separator: true },
                { text: "Automatically Hide: Smart", icon: "auto_mode", checked: Config.dockAutohide === "smart", action: () => Config.dockAutohide = "smart" },
                { text: "Automatically Hide: Always", icon: "visibility_off", checked: Config.dockAutohide === "always", action: () => Config.dockAutohide = "always" },
                { text: "Always Show Dock", icon: "dock_to_bottom", checked: Config.dockAutohide === "never", action: () => Config.dockAutohide = "never" },
                { text: "Magnification", icon: "zoom_in", checked: Config.dockMagnify, action: () => Config.dockMagnify = !Config.dockMagnify }
            ];
        } else if (it.type === "trash") {
            rows = [
                { header: "Trash" },
                { text: "Open", icon: "folder_open", action: () => Shell.run(Config.fileManager + " trash:///") },
                { separator: true },
                { text: "Empty Trash…", icon: "delete_forever", destructive: true, enabled: dock.trashFull, action: () => Shell.ask({ title: "Are you sure you want to permanently erase the items in the Trash?", body: "You can’t undo this action.", icon: "delete_forever", confirm: "Empty Trash", destructive: true, action: () => { Shell.run("gio trash --empty"); dock.trashFull = false; } }) }
            ];
        } else {
            const wins = [];
            for (const a of it.appIds) for (const t of Windows.of(a)) wins.push(t);
            rows.push({ header: cell.label });
            for (const t of wins.slice(0, 8)) {
                const tt = t;
                rows.push({ text: tt.title || cell.label, icon: "select_window", right: tt.workspace ? "WS " + tt.workspace.name : "", action: () => Windows.focus(tt) });
            }
            if (wins.length) rows.push({ separator: true });
            if (it.entry) {
                rows.push({ text: "New Window", icon: "add", action: () => Apps.launch(it.entry) });
                for (const act of it.entry.actions.slice(0, 4)) {
                    const a = act;
                    rows.push({ text: a.name, icon: "subdirectory_arrow_right", action: () => Apps.launchAction(it.entry, a) });
                }
                rows.push({ text: "Keep in Dock", icon: "keep", checked: Config.isPinned(it.entry.id), action: () => Config.togglePin(it.entry.id) });
                rows.push({ text: "Deep Focus on " + cell.label, icon: "center_focus_strong", action: () => Focus.start(it.entry, it.appIds[0] || null, Config.focusMinutes) });
            }
            if (wins.length) {
                rows.push({ text: "Bring All to This Workspace", icon: "move_down", action: () => { for (const t of wins) Windows.moveHere(t); } });
                rows.push({ separator: true });
                rows.push({ text: "Quit", icon: "cancel", destructive: true, action: () => { for (const a of it.appIds) Windows.quitApp(a); } });
            }
        }
        Shell.showMenu(sname, p.x + cell.width / 2 - 115, overlayY, rows, true);
    }
}
