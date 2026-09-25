import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.services
import qs.widgets

// Three menu-bar popups sharing one surface (kind = Shell.panel):
//   battery — charge, health, power mode      Keys: P cycle · 1/2/3 pick
//   system  — CPU, memory, top processes       Keys: M more (btop)
//   disk    — free space, space hogs           Keys: E empty Trash · R rescan · M more (duf)
PopupLayer {
    id: sp
    ns: "mac-panel"
    persistent: true
    panelItem: panel
    readonly property string sname: screen ? screen.name : ""
    readonly property var kinds: ["battery", "system", "disk"]
    open: kinds.indexOf(Shell.panel) >= 0 && Shell.screenName === sname
    property string kind: "system"            // kept during the close animation
    onDismissed: Shell.close()
    onOpenChanged: { if (open) { kind = Shell.panel; keys.forceActiveFocus(); } sync(); }
    Connections { target: Shell; function onPanelChanged() { if (sp.open) { sp.kind = Shell.panel; sp.sync(); } } }
    function sync() {
        Sys.detailed = open && kind === "system";
        Sys.diskDetailed = open && kind === "disk";
        if (Sys.detailed) Sys.sample();
        if (Sys.diskDetailed) { Sys.refreshDisks(); Sys.scanHogs(); }
    }

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBat: dev && dev.ready && dev.isLaptopBattery
    readonly property bool charging: hasBat && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge)

    function openMore() {
        Shell.close();
        if (kind === "disk") Quickshell.execDetached([Config.terminal, "--hold", "-e", "duf"]);
        else Shell.run(Config.terminal + " -e btop");
    }
    function inTerminal(cmd) { Shell.close(); Quickshell.execDetached([Config.terminal, "--hold", "-e", "bash", "-c", cmd]); }
    function emptyTrash() {
        Shell.close();
        Shell.ask({ title: "Are you sure you want to permanently erase the items in the Trash?", body: "You can’t undo this action.", icon: "delete_forever", confirm: "Empty Trash", destructive: true, action: () => Shell.run("gio trash --empty") });
    }
    function diskName(d) { return d.mount === "/" ? "System" : d.mount === "/boot" ? "Boot" : d.mount.slice(d.mount.lastIndexOf("/") + 1) || d.mount; }
    function fmtTime(secs) {
        if (!(secs > 0)) return "";
        const h = Math.floor(secs / 3600), m = Math.round((secs % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " min";
    }
    readonly property var profileInfo: ({
        "power-saver": { label: "Low Power", icon: "battery_saver" },
        "balanced": { label: "Balanced", icon: "balance" },
        "performance": { label: "Performance", icon: "speed" }
    })

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) Shell.close();
            else if (sp.kind === "battery" && e.key === Qt.Key_P) Sys.cycleProfile();
            else if (sp.kind === "battery" && e.key >= Qt.Key_1 && e.key <= Qt.Key_3 && Sys.profiles[e.key - Qt.Key_1]) Sys.setProfile(Sys.profiles[e.key - Qt.Key_1]);
            else if (sp.kind !== "battery" && e.key === Qt.Key_M) sp.openMore();
            else if (sp.kind === "disk" && e.key === Qt.Key_E) sp.emptyTrash();
            else if (sp.kind === "disk" && e.key === Qt.Key_R) Sys.scanHogs();
            else return;
            e.accepted = true;
        }
    }

    Glass {
        id: panel
        width: 340
        height: col.implicitHeight + 28
        radius: 28
        x: Math.max(8, Math.min(sp.width - width - 8, Shell.panelX - width / 2))
        y: 6 - (1 - sp.t) * 8
        opacity: sp.t
        scale: 0.97 + 0.03 * sp.t
        transformOrigin: Item.Top
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: col
            x: 14; y: 14
            width: panel.width - 28
            spacing: 10

            // ---- Battery ---------------------------------------------------
            CCTile {
                visible: sp.kind === "battery"
                Layout.fillWidth: true
                Layout.preferredHeight: batCol.implicitHeight + 26
                radius: 22
                ColumnLayout {
                    id: batCol
                    x: 16; y: 13
                    width: parent.width - 32
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        T { text: "Battery"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        T { text: sp.hasBat ? Math.round(sp.dev.percentage * 100) + "%" : ""; font.pixelSize: 20; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 8; radius: 4
                        color: Theme.field
                        Rectangle {
                            height: parent.height; radius: 4
                            width: parent.width * (sp.hasBat ? sp.dev.percentage : 0)
                            color: sp.charging ? Theme.systemGreen : sp.hasBat && sp.dev.percentage <= 0.15 ? Theme.systemRed : Theme.text
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 3
                        T { text: "Status"; font.pixelSize: 12; color: Theme.text2 }
                        T {
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12
                            text: !sp.hasBat ? "" : sp.dev.state === UPowerDeviceState.FullyCharged ? "Fully charged"
                                : sp.charging ? "Charging" + (sp.fmtTime(sp.dev.timeToFull) ? " · full in " + sp.fmtTime(sp.dev.timeToFull) : "")
                                : "On battery" + (sp.fmtTime(sp.dev.timeToEmpty) ? " · " + sp.fmtTime(sp.dev.timeToEmpty) + " left" : "")
                        }
                        T { text: "Power draw"; font.pixelSize: 12; color: Theme.text2 }
                        T { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12; text: sp.hasBat ? sp.dev.changeRate.toFixed(1) + " W" : "" }
                        T { visible: Sys.health >= 0; text: "Health"; font.pixelSize: 12; color: Theme.text2 }
                        T {
                            visible: Sys.health >= 0
                            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12
                            text: Math.round(Sys.health * 100) + "% of design capacity" + (Sys.cycles > 0 ? " · " + Sys.cycles + " cycles" : "")
                            color: Sys.health < 0.6 ? Theme.systemOrange : Theme.text
                        }
                        T { visible: Sys.chargeLimit < 100; text: "Charge limit"; font.pixelSize: 12; color: Theme.text2 }
                        T { visible: Sys.chargeLimit < 100; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pixelSize: 12; text: Sys.chargeLimit + "%" }
                    }
                }
            }

            // ---- Power mode (replaces the old "Power Settings…") ------------
            CCTile {
                visible: sp.kind === "battery" && Sys.hasProfiles
                Layout.fillWidth: true
                Layout.preferredHeight: pmCol.implicitHeight + 26
                radius: 22
                ColumnLayout {
                    id: pmCol
                    x: 14; y: 13
                    width: parent.width - 28
                    spacing: 8
                    T { Layout.leftMargin: 2; text: "Power Mode"; font.pixelSize: 13; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: Sys.profiles
                            Hoverable {
                                id: pm
                                required property string modelData
                                readonly property bool cur: Sys.profile === modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1          // equal thirds
                                implicitHeight: 54
                                radius: 14
                                color: cur ? Theme.accent : hovered ? Theme.tileHover : Theme.field
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Sym {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        name: (sp.profileInfo[pm.modelData] || {}).icon || "bolt"
                                        size: 20; filled: true
                                        color: pm.cur ? Theme.accentText : Theme.text
                                    }
                                    T {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Math.min(implicitWidth, pm.width - 8)
                                        horizontalAlignment: Text.AlignHCenter
                                        text: (sp.profileInfo[pm.modelData] || { label: pm.modelData }).label
                                        font.pixelSize: 11; font.weight: Font.Medium
                                        color: pm.cur ? Theme.accentText : Theme.text
                                    }
                                }
                                onClicked: Sys.setProfile(pm.modelData)
                            }
                        }
                    }
                }
            }

            // ---- CPU ---------------------------------------------------------
            CCTile {
                visible: sp.kind === "system"
                Layout.fillWidth: true
                Layout.preferredHeight: cpuCol.implicitHeight + 26
                radius: 22
                ColumnLayout {
                    id: cpuCol
                    x: 16; y: 13
                    width: parent.width - 32
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            T { text: "CPU"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            T { text: Sys.model || (Sys.nproc + " threads"); font.pixelSize: 11; color: Theme.text2; Layout.maximumWidth: 190 }
                        }
                        Item { Layout.fillWidth: true }
                        T { text: Math.round(Sys.cpu * 100) + "%"; font.pixelSize: 20; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                    }
                    Sparkline {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        values: Sys.history
                        color: Sys.cpu > 0.85 ? Theme.systemRed : Theme.accent
                    }
                    // Per-core bars
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Repeater {
                            model: Sys.cores
                            Rectangle {
                                required property real modelData
                                Layout.fillWidth: true
                                height: 22; radius: 3
                                color: Theme.field
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(2, parent.height * modelData)
                                    radius: 3
                                    color: modelData > 0.85 ? Theme.systemOrange : Theme.text2
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 2
                        columnSpacing: 6
                        Repeater {
                            model: [
                                { k: "Temp", v: Sys.temp >= 0 ? Math.round(Sys.temp) + "°C" : "—", c: Sys.temp >= 0 ? Sys.tempColor(Sys.temp) : Theme.text },
                                { k: "Fan", v: Sys.fan >= 0 ? Sys.fan + " rpm" : "—", c: Theme.text },
                                { k: "Clock", v: Sys.freq > 0 ? Sys.freq.toFixed(2) + " GHz" : "—", c: Theme.text },
                                { k: "Load", v: Sys.load.split("  ")[0] || "—", c: Theme.text }
                            ]
                            ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                T { text: modelData.k; font.pixelSize: 10; color: Theme.text3 }
                                T { text: modelData.v; font.pixelSize: 12; font.weight: Font.DemiBold; color: modelData.c }
                            }
                        }
                    }
                }
            }

            // ---- Memory -------------------------------------------------------
            CCTile {
                visible: sp.kind === "system"
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                radius: 20
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16; anchors.rightMargin: 16
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        T { text: "Memory"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        T {
                            text: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GB" + (Sys.swapUsed > 0.05 ? "  ·  swap " + Sys.swapUsed.toFixed(1) + " GB" : "")
                            font.pixelSize: 12; color: Theme.text2
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6; radius: 3
                        color: Theme.field
                        Rectangle {
                            height: parent.height; radius: 3
                            width: parent.width * (Sys.memTotal > 0 ? Sys.memUsed / Sys.memTotal : 0)
                            color: Sys.memTotal > 0 && Sys.memUsed / Sys.memTotal > 0.9 ? Theme.systemOrange : Theme.text
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                }
            }

            // ---- Top processes -------------------------------------------------
            CCTile {
                visible: sp.kind === "system"
                Layout.fillWidth: true
                Layout.preferredHeight: procCol.implicitHeight + 22
                radius: 20
                ColumnLayout {
                    id: procCol
                    x: 16; y: 11
                    width: parent.width - 32
                    spacing: 3
                    T { text: "Top Processes"; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.bottomMargin: 2 }
                    Repeater {
                        model: Sys.top.slice(0, 5)
                        RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            T { Layout.fillWidth: true; text: modelData.name; font.pixelSize: 12 }
                            T { text: modelData.mem.toFixed(1) + "% mem"; font.pixelSize: 11; color: Theme.text3 }
                            T { Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight; text: modelData.cpu.toFixed(1) + "%"; font.pixelSize: 12; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                        }
                    }
                    T { visible: Sys.top.length === 0; text: "Sampling…"; font.pixelSize: 12; color: Theme.text3 }
                }
            }

            // ---- Disks ----------------------------------------------------------
            Repeater {
                model: sp.kind === "disk" ? Sys.disks : []
                CCTile {
                    id: dt
                    required property var modelData
                    readonly property real frac: modelData.size > 0 ? modelData.used / modelData.size : 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: dCol.implicitHeight + 26
                    radius: 22
                    ColumnLayout {
                        id: dCol
                        x: 16; y: 13
                        width: parent.width - 32
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Sym { name: dt.modelData.mount === "/" ? "hard_drive" : dt.modelData.dev.indexOf("/dev/sd") === 0 ? "usb" : "hard_drive_2"; size: 26; filled: true; color: Theme.text2 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                T { Layout.fillWidth: true; text: sp.diskName(dt.modelData); font.pixelSize: 13; font.weight: Font.DemiBold }
                                T { Layout.fillWidth: true; text: dt.modelData.mount + " · " + dt.modelData.fs + " · " + dt.modelData.dev.replace("/dev/", ""); font.pixelSize: 11; color: Theme.text3 }
                            }
                            ColumnLayout {
                                spacing: 0
                                T { Layout.alignment: Qt.AlignRight; text: Sys.human(dt.modelData.avail); font.pixelSize: 17; font.weight: Font.Bold; color: dt.frac > 0.95 ? Theme.systemRed : dt.frac > 0.85 ? Theme.systemOrange : Theme.text }
                                T { Layout.alignment: Qt.AlignRight; text: "free of " + Sys.human(dt.modelData.size); font.pixelSize: 11; color: Theme.text2 }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 8; radius: 4
                            color: Theme.field
                            Rectangle {
                                height: parent.height; radius: 4
                                width: parent.width * dt.frac
                                color: dt.frac > 0.95 ? Theme.systemRed : dt.frac > 0.85 ? Theme.systemOrange : Theme.accent
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                        T { text: Sys.human(dt.modelData.used) + " used (" + Math.round(dt.frac * 100) + "%)"; font.pixelSize: 11; color: Theme.text2 }
                    }
                }
            }

            // Space hogs (what's worth cleaning)
            CCTile {
                visible: sp.kind === "disk"
                Layout.fillWidth: true
                Layout.preferredHeight: hogCol.implicitHeight + 22
                radius: 20
                ColumnLayout {
                    id: hogCol
                    x: 16; y: 11
                    width: parent.width - 32
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 2
                        T { Layout.fillWidth: true; text: "Space Used By"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        T { visible: Sys.scanning; text: "Scanning…"; font.pixelSize: 11; color: Theme.text3 }
                        Hoverable {
                            visible: !Sys.scanning
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            Sym { anchors.centerIn: parent; name: "refresh"; size: 15; color: Theme.text2 }
                            onClicked: Sys.scanHogs()
                        }
                    }
                    Repeater {
                        model: sp.kind === "disk" ? Sys.spaceHogs : []
                        RowLayout {
                            id: hog
                            required property var modelData
                            readonly property var act: modelData.label === "Trash" ? { t: "Empty", f: () => sp.emptyTrash() }
                                                     : modelData.label === "Package cache" ? { t: "Clean", f: () => sp.inTerminal("sudo paccache -rk1 && echo && echo 'Done — kept the newest version of each package.'") }
                                                     : modelData.label === "Journal logs" ? { t: "Trim", f: () => sp.inTerminal("sudo journalctl --vacuum-size=200M") }
                                                     : { t: "Open", f: () => { Shell.close(); Quickshell.execDetached([Config.fileManager, modelData.path]); } }
                            Layout.fillWidth: true
                            spacing: 8
                            T { Layout.fillWidth: true; text: modelData.label; font.pixelSize: 12 }
                            T { text: Sys.human(modelData.bytes); font.pixelSize: 12; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                            Hoverable {
                                implicitWidth: actT.implicitWidth + 16; implicitHeight: 22; radius: 11
                                color: hovered ? Theme.tileHover : Theme.field
                                T { id: actT; anchors.centerIn: parent; text: hog.act.t; font.pixelSize: 11; font.weight: Font.Medium }
                                onClicked: hog.act.f()
                            }
                        }
                    }
                    T { visible: !Sys.scanning && Sys.spaceHogs.length === 0; text: "Nothing notable found"; font.pixelSize: 12; color: Theme.text3 }
                }
            }

            // ---- More -----------------------------------------------------------
            Hoverable {
                visible: sp.kind !== "battery"
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 19
                color: hovered ? Theme.tileHover : Theme.tile
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Sym { anchors.verticalCenter: parent.verticalCenter; name: "monitoring"; size: 17; color: Theme.text }
                    T { anchors.verticalCenter: parent.verticalCenter; text: sp.kind === "disk" ? "More in duf…" : "More in btop…"; font.pixelSize: 13; font.weight: Font.Medium }
                    Kbd { anchors.verticalCenter: parent.verticalCenter; keys: ["M"] }
                }
                onClicked: sp.openMore()
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Hint { label: "Close"; keys: ["Esc"] }
                Hint { visible: sp.kind === "battery" && Sys.hasProfiles; label: "Power mode"; keys: ["P"] }
                Hint { visible: sp.kind === "battery" && Sys.hasProfiles; label: "Pick"; keys: ["1", "2", "3"] }
                Hint { visible: sp.kind === "disk"; label: "Empty Trash"; keys: ["E"] }
                Hint { visible: sp.kind === "disk"; label: "Rescan"; keys: ["R"] }
            }
        }
    }
}
