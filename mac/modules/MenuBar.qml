import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs.services
import qs.widgets

// macOS menu bar: logo menu · active app · window title · workspaces | status items · clock
PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    implicitHeight: Config.barHeight
    color: "transparent"
    WlrLayershell.namespace: Config.barGlass ? "mac-bar-glass" : "mac-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property string sname: screen ? screen.name : ""
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var activeWs: monitor ? monitor.activeWorkspace : null
    readonly property var activeTop: {
        const t = Hyprland.activeToplevel;
        if (!t || !t.workspace || !activeWs || t.workspace.id !== activeWs.id) return null;
        return t;
    }
    readonly property string activeAppId: activeTop ? (activeTop.wayland ? activeTop.wayland.appId : (activeTop.lastIpcObject.class || "")) : ""
    readonly property string activeTitle: activeTop ? activeTop.title : ""

    readonly property var occupied: Hyprland.workspaces.values
        .filter(w => w.id > 0 && w.monitor && w.monitor.name === sname && (w.toplevels.values.length > 0 || (activeWs && w.id === activeWs.id)))
        .sort((a, b) => a.id - b.id)
    function cycleWs(dir) {
        const ids = occupied.map(w => w.id);
        if (ids.length < 2 || !activeWs) return;
        const i = ids.indexOf(activeWs.id);
        const next = ids[(i + dir + ids.length) % ids.length];
        Shell.dispatch(`hl.dsp.focus({ workspace = ${next} })`);
    }

    IdleInhibitor { window: bar; enabled: Config.keepAwake }
    Component.onCompleted: Shell.registerBar(sname, bar)
    onSnameChanged: Shell.registerBar(sname, bar)

    function openSystem(item, kind) {
        const p = item.mapToItem(null, 0, 0);
        Shell.panelX = p.x + item.width / 2;
        Shell.toggle(kind, sname);
    }

    function menuAt(item, items) {
        const p = item.mapToItem(null, 0, 0);
        Shell.showMenu(sname, p.x, 4, items, false);
    }

    // Optional glass strip (Config.barGlass); Tahoe default is fully transparent.
    Rectangle {
        anchors.fill: parent
        visible: Config.barGlass
        color: Theme.glass
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.separator }
    }
    // Faint top vignette keeps text legible on busy wallpapers.
    Rectangle {
        anchors.fill: parent
        visible: !Config.barGlass
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.barOnLight ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.16) }
            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
        }
    }

    // Scroll anywhere on the left half to switch workspaces.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Shell.closeAll()      // empty bar space dismisses popups
        onWheel: w => bar.cycleWs(w.angleDelta.y > 0 ? -1 : 1)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 2

        // ---- Logo / session menu --------------------------------------
        BarButton {
            id: logoBtn
            implicitWidth: 34
            active: Shell.menuOpen && Shell.menuScreen === bar.sname && Shell.menuPos.x < 40
            TintedIcon {
                anchors.centerIn: parent
                width: 16; height: 16
                source: Quickshell.shellPath("assets/logo.svg")
                color: Theme.barText
            }
            onClicked: Shell.sessionMenu(bar.sname, logoBtn.mapToItem(null, 0, 0).x, 4)
        }

        // ---- Workspaces (occupied only) -----------------------------------
        Row {
            Layout.leftMargin: 4
            Layout.rightMargin: 8
            spacing: 4
            Repeater {
                model: ScriptModel { values: bar.occupied }
                delegate: BarButton {
                    id: wsBtn
                    required property var modelData
                    readonly property bool current: bar.activeWs && modelData.id === bar.activeWs.id
                    readonly property var apps: {
                        const seen = [];
                        for (const t of modelData.toplevels.values) {
                            const id = t.wayland ? t.wayland.appId : (t.lastIpcObject.class || "");
                            if (id && seen.indexOf(id) < 0) seen.push(id);
                        }
                        return seen;
                    }
                    implicitHeight: 22
                    implicitWidth: wsRow.implicitWidth + 14
                    radius: 11
                    color: current ? Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, pressed ? 0.3 : 0.2)
                                   : pressed ? Theme.barHover : hovered ? Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.10) : "transparent"
                    border.width: current ? 0 : 1
                    border.color: Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.14)
                    Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Row {
                        id: wsRow
                        anchors.centerIn: parent
                        spacing: 5
                        T {
                            anchors.verticalCenter: parent.verticalCenter
                            text: wsBtn.modelData.name
                            font.pixelSize: 12
                            font.weight: wsBtn.current ? Font.Bold : Font.Medium
                            color: wsBtn.current ? Theme.barText : Theme.barText2
                        }
                        Repeater {
                            model: wsBtn.apps.slice(0, 4)
                            IconImage {
                                required property string modelData
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 14
                                source: Apps.iconForAppId(modelData)
                                opacity: wsBtn.current ? 1 : 0.8
                            }
                        }
                    }
                    onClicked: Shell.dispatch(`hl.dsp.focus({ workspace = ${modelData.id} })`)
                }
            }
        }

        // ---- Active application ---------------------------------------
        BarButton {
            id: appBtn
            implicitWidth: appRow.implicitWidth + 16
            RowLayout {
                id: appRow
                anchors.centerIn: parent
                spacing: 7
                IconImage {
                    visible: bar.activeAppId !== ""
                    implicitSize: 16
                    source: Apps.iconForAppId(bar.activeAppId)
                }
                T {
                    text: bar.activeAppId !== "" ? Apps.nameForAppId(bar.activeAppId) : "Desktop"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: Theme.barText
                }
            }
            onClicked: {
                const t = bar.activeTop;
                const entry = Apps.forAppId(bar.activeAppId);
                if (!t) { Shell.sessionMenu(bar.sname, appBtn.mapToItem(null, 0, 0).x, 4); return; }
                const addr = Windows.addr(t);
                bar.menuAt(appBtn, [
                    { header: Apps.nameForAppId(bar.activeAppId) },
                    { text: "New Window", icon: "add", enabled: !!entry, action: () => Apps.launch(entry) },
                    { separator: true },
                    { text: "Float Window", icon: "picture_in_picture", shortcut: "Super O", action: () => Shell.dispatch(`hl.dsp.window.float({ action = "toggle", window = "address:${addr}" })`) },
                    { text: "Fullscreen", icon: "fullscreen", shortcut: "Super F", action: () => Shell.dispatch(`hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })`) },
                    { text: "Maximize", icon: "open_in_full", shortcut: "Super ⇧ F", action: () => Shell.dispatch(`hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })`) },
                    { text: "Pin on All Workspaces", icon: "push_pin", action: () => Shell.dispatch(`hl.dsp.window.pin({ window = "address:${addr}" })`) },
                    { text: "Keep in Dock", icon: "keep", checked: entry && Config.isPinned(entry.id), enabled: !!entry, action: () => Config.togglePin(entry.id) },
                    { separator: true },
                    { text: "Close Window", icon: "close", shortcut: "Super Q", action: () => Shell.dispatch(`hl.dsp.window.close({ window = "address:${addr}" })`) },
                    { text: "Quit " + Apps.nameForAppId(bar.activeAppId), icon: "cancel", destructive: true, action: () => Windows.quitApp(bar.activeAppId) }
                ]);
            }
        }

        // ---- Window title ---------------------------------------------
        T {
            Layout.maximumWidth: Math.max(80, bar.width * 0.34)
            Layout.leftMargin: 4
            visible: bar.activeTitle !== "" && bar.activeTitle !== Apps.nameForAppId(bar.activeAppId)
            text: bar.activeTitle
            color: Theme.barText2
            font.pixelSize: 13
        }

        Item { Layout.fillWidth: true }

        // ---- System tray ---------------------------------------------
        Row {
            spacing: 0
            Repeater {
                // nm-applet is hidden: Wi-Fi lives in the status item + Control Center.
                model: ScriptModel { values: SystemTray.items.values.filter(i => i.id !== "nm-applet") }
                delegate: BarButton {
                    id: trayBtn
                    required property var modelData
                    implicitWidth: 28
                    readonly property bool symbolic: modelData.icon.indexOf("symbolic") >= 0
                    IconImage {
                        id: trayIcon
                        anchors.centerIn: parent
                        implicitSize: 16
                        layer.enabled: trayBtn.symbolic
                        layer.effect: MultiEffect { colorization: 1; colorizationColor: Theme.barText; brightness: 1 }
                        source: {
                            const i = trayBtn.modelData.icon;
                            if (i.indexOf("?path=") >= 0) {
                                const parts = i.split("?path="); const name = parts[0], path = parts[1];
                                return "file://" + path + "/" + name.slice(name.lastIndexOf("/") + 1);
                            }
                            return i;
                        }
                    }
                    onClicked: m => {
                        if (modelData.onlyMenu && modelData.hasMenu) Shell.showMenu(bar.sname, trayBtn.mapToItem(null, 0, 0).x, 4, { tray: modelData.menu }, false);
                        else modelData.activate();
                    }
                    onMiddleClicked: modelData.secondaryActivate()
                    onRightClicked: if (modelData.hasMenu) Shell.showMenu(bar.sname, trayBtn.mapToItem(null, 0, 0).x, 4, { tray: modelData.menu }, false)
                    mouse.onWheel: w => modelData.scroll(w.angleDelta.y / 120, false)
                }
            }
        }

        // ---- Now playing -----------------------------------------------
        BarButton {
            visible: Media.active && Media.player.isPlaying
            implicitWidth: npRow.implicitWidth + 14
            Row {
                id: npRow
                anchors.centerIn: parent
                spacing: 5
                Sym { anchors.verticalCenter: parent.verticalCenter; name: "graphic_eq"; size: 16; color: Theme.barText }
                T {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 160)
                    text: Media.player ? Media.player.trackTitle : ""
                    color: Theme.barText
                    font.pixelSize: 12
                }
            }
            onClicked: Shell.toggle("controlcenter", bar.sname)
        }

        // ---- Keyboard layout -------------------------------------------
        BarButton {
            visible: Keyboard.count > 1
            implicitWidth: 32
            Rectangle {
                anchors.centerIn: parent
                width: 22; height: 16; radius: 4
                color: "transparent"
                border.width: 1.2
                border.color: Theme.barText
                T { anchors.centerIn: parent; text: Keyboard.short; font.pixelSize: 9; font.weight: Font.Bold; color: Theme.barText }
            }
            onClicked: Keyboard.next()
        }

        // ---- CPU glance (usage · temperature) -> System panel -------------
        BarButton {
            id: cpuBtn
            implicitWidth: cpuRow.implicitWidth + 14
            active: Shell.isOpen("system", bar.sname)
            Row {
                id: cpuRow
                anchors.centerIn: parent
                spacing: 4
                Sym { anchors.verticalCenter: parent.verticalCenter; name: "memory"; size: 16; color: Theme.barText }
                T {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Sys.cpu * 100) + "%"
                    font.pixelSize: 12; font.features: { "tnum": 1 }
                    color: Theme.barText
                    width: 30
                }
                T {
                    visible: Sys.temp >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Sys.temp) + "°"
                    font.pixelSize: 12; font.features: { "tnum": 1 }
                    color: Sys.temp >= 85 ? Theme.systemRed : Sys.temp >= 70 ? Theme.systemOrange : Theme.barText2
                }
            }
            onClicked: bar.openSystem(cpuBtn, "system")
        }

        // ---- Disk glance (free space on /) -> Disk panel ----------------------
        BarButton {
            id: diskBtn
            visible: Sys.mainDisk !== null
            implicitWidth: diskRow.implicitWidth + 14
            active: Shell.isOpen("disk", bar.sname)
            readonly property real frac: Sys.mainDisk && Sys.mainDisk.size > 0 ? Sys.mainDisk.used / Sys.mainDisk.size : 0
            Row {
                id: diskRow
                anchors.centerIn: parent
                spacing: 4
                Sym { anchors.verticalCenter: parent.verticalCenter; name: "hard_drive"; size: 15; color: Theme.barText }
                T {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.mainDisk ? Math.round(Sys.mainDisk.avail / 1e9) + "G" : ""
                    font.pixelSize: 12; font.features: { "tnum": 1 }
                    color: diskBtn.frac > 0.95 ? Theme.systemRed : diskBtn.frac > 0.85 ? Theme.systemOrange : Theme.barText
                }
            }
            onClicked: bar.openSystem(diskBtn, "disk")
        }

        // ---- Battery -------------------------------------------------------
        BarButton {
            id: batBtn
            readonly property var dev: UPower.displayDevice
            readonly property bool has: dev && dev.ready && dev.isLaptopBattery
            readonly property real pct: has ? dev.percentage : 1
            readonly property bool charging: has && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)
            visible: has
            implicitWidth: batRow.implicitWidth + 14
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 6
                T { anchors.verticalCenter: parent.verticalCenter; text: Math.round(batBtn.pct * 100) + "%"; font.pixelSize: 12; color: Theme.barText }
                // Drawn battery glyph, like macOS.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 12
                    Rectangle {
                        id: shell
                        width: 23; height: 12; radius: 3.5
                        color: "transparent"
                        border.width: 1.1
                        border.color: Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.55)
                        Rectangle {
                            x: 2; y: 2
                            height: parent.height - 4
                            width: Math.max(1.5, (parent.width - 4) * batBtn.pct)
                            radius: 1.8
                            color: batBtn.pct <= 0.1 && !batBtn.charging ? Theme.systemRed : batBtn.charging ? Theme.systemGreen : Theme.barText
                        }
                    }
                    Rectangle { x: 24; y: 4; width: 1.8; height: 4; radius: 1; color: Qt.rgba(Theme.barText.r, Theme.barText.g, Theme.barText.b, 0.55) }
                    Sym { visible: batBtn.charging; anchors.centerIn: shell; name: "bolt"; filled: true; size: 12; color: Theme.barOnLight ? "white" : "#1d1d1f" }
                }
            }
            active: Shell.isOpen("battery", bar.sname)
            onClicked: bar.openSystem(batBtn, "battery")
        }

        // ---- Wi-Fi + Control Center (one target, one highlight) -------------
        BarButton {
            implicitWidth: ccRow.implicitWidth + 16
            active: Shell.isOpen("controlcenter", bar.sname)
            Row {
                id: ccRow
                anchors.centerIn: parent
                spacing: 12
                Sym { anchors.verticalCenter: parent.verticalCenter; name: Net.icon(); size: 17; filled: true; color: Theme.barText }
                Sym { anchors.verticalCenter: parent.verticalCenter; name: "toggle_on"; size: 18; filled: true; color: Theme.barText }
            }
            onClicked: Shell.toggle("controlcenter", bar.sname)
        }

        // ---- Clock -> Notification Center -----------------------------------
        BarButton {
            implicitWidth: clockRow.implicitWidth + 14
            active: Shell.isOpen("notifications", bar.sname)
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 6
                Sym {
                    visible: Config.dnd
                    anchors.verticalCenter: parent.verticalCenter
                    name: "dark_mode"; filled: true; size: 14; color: Theme.barText
                }
                T {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM") + "   " + Qt.formatDateTime(clock.date, Config.clock24h ? "HH:mm" : "h:mm AP")
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    color: Theme.barText
                }
                Rectangle {
                    visible: Notifs.count > 0 && !Shell.isOpen("notifications", bar.sname)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }
            }
            onClicked: Shell.toggle("notifications", bar.sname)
        }
    }
}
