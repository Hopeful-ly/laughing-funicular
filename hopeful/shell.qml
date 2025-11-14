import Quickshell                    // PanelWindow, etc.
import Quickshell.Io                 // Process, StdioCollector
import Quickshell.Hyprland           // Hyprland singleton
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower    // Battery info via UPower
import Quickshell.Widgets            // IconImage
import QtQuick
import QtQuick.Layouts
import QtQml                         // ListModel, ListElement
import QtQuick.Effects               // MultiEffect (modern glow)

/*
 * MAGI Core Celestial Monitoring System - Panel UI
 *
 * v2.1:
 * - Fix: ObjectRepeater → Repeater (Qt6 / Quickshell recommendation)
 * - Battery indicator (UPower.displayDevice)
 * - Hyprland-native workspaces, swaync toggle, system tray, MultiEffect glow
 */

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 38
    color: "transparent"

    // --- NERV / MAGI STYLE THEME -------------------------------------------
    property color colorBackground: "#05070c"
    property color colorBackgroundEnd: "#0a101f"
    property color accentColor: "#00ffaa"
    property color accentSoft: "#00c4aa"
    property color warningColor: "#ff9900"
    property color dangerColor: "#ff3355"
    property color infoColor: "#55aaff"
    property color textDim: "#6aa9a9"
    property color textPrimary: "#e0f0f0"
    property string panelFont: "monospace"

    // --- SYSTEM STATE ------------------------------------------------------
    property string geoLocation: "ACQUIRING IP VECTOR..."
    property string localIp: "0.0.0.0"
    property string subnet: "0.0.0.0/0"
    property string publicIp: "UNKNOWN"
    property bool online: false
    property string twingateConnected: "..."

    // --- WORKSPACE STATE (Hyprland native) --------------------------------
    // Map Hyprland workspace ids 1–9 -> 0–8 for the 9 planets
    property int currentWorkspaceIndex: {
        const ws = Hyprland.focusedWorkspace;
        if (ws && ws.id > 0 && ws.id <= planetModel.count)
            return ws.id - 1;
        return 0;
    }

    // --- PLANET/WORKSPACE DATA MODEL ---------------------------------------
    ListModel {
        id: planetModel

        ListElement {
            name: "Mercury"
            symbol: "☿"
            color: "#C0C0C8"
            accent: "#6FB1FF"
            glow: 0.15
        }
        ListElement {
            name: "Venus"
            symbol: "♀"
            color: "#FFCC7A"
            accent: "#FF9E3D"
            glow: 0.25
        }
        ListElement {
            name: "Earth"
            symbol: "⊕"
            color: "#66CFFF"
            accent: "#00E5A8"
            glow: 0.35
        }
        ListElement {
            name: "Mars"
            symbol: "♂"
            color: "#FF5533"
            accent: "#FF7A4A"
            glow: 0.22
        }
        ListElement {
            name: "Jupiter"
            symbol: "♃"
            color: "#EDE2C8"
            accent: "#D9A75C"
            glow: 0.18
        }
        ListElement {
            name: "Saturn"
            symbol: "♄"
            color: "#D7C48A"
            accent: "#E8D07A"
            glow: 0.20
        }
        ListElement {
            name: "Uranus"
            symbol: "♅"
            color: "#B3F4FF"
            accent: "#7EE8F0"
            glow: 0.28
        }
        ListElement {
            name: "Neptune"
            symbol: "♆"
            color: "#6A8BFF"
            accent: "#4F6CFF"
            glow: 0.30
        }
        ListElement {
            name: "Pluto"
            symbol: "♇"
            color: "#C8C6C0"
            accent: "#9FA5B0"
            glow: 0.12
        }
    }

    // --- Reusable Components -----------------------------------------------
    Component {
        id: separator
        Rectangle {
            width: 1
            height: 18
            color: root.textDim
            opacity: 0.2
        }
    }

    // --- BACKGROUND --------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: root.colorBackground
            }
            GradientStop {
                position: 1.0
                color: root.colorBackgroundEnd
            }
        }
    }

    // ====================== TOP BAR LAYOUT ================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 12

        // ---- LEFT: NERV Logo + System Title -------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 8

            Item {
                id: logoWrapper
                width: 18
                height: 18

                Rectangle {
                    id: logoBg
                    anchors.fill: parent
                    radius: 3
                    border.color: root.accentSoft
                    border.width: 1
                    color: "#060a12"
                    antialiasing: true

                    Canvas {
                        anchors.fill: parent
                        antialiasing: true
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.beginPath();
                            ctx.moveTo(width / 2, 3);
                            ctx.lineTo(width - 3, height - 3);
                            ctx.lineTo(3, height - 3);
                            ctx.closePath();
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = root.accentColor;
                            ctx.stroke();
                        }
                    }
                }

                // Modern Qt6 glow using MultiEffect
                MultiEffect {
                    anchors.fill: logoBg
                    source: logoBg
                    shadowEnabled: true
                    shadowColor: root.accentColor
                    shadowOpacity: 0.8
                    shadowBlur: 1.0
                    shadowScale: 1.4
                    blurEnabled: false
                    autoPaddingEnabled: true
                }
            }

            ColumnLayout {
                spacing: -2

                Text {
                    text: "NERV CELESTIAL MONITORING SYSTEM"
                    color: root.accentColor
                    font.bold: true
                    font.pixelSize: 13
                    font.family: root.panelFont
                    font.letterSpacing: 1
                }

                RowLayout {
                    spacing: 10

                    Text {
                        text: "MAGI CORE v1.0.2"
                        color: root.textDim
                        font.pixelSize: 10
                        font.family: root.panelFont
                    }

                    Text {
                        id: netStatusText
                        text: root.online ? "MAGI NET: ONLINE" : "MAGI NET: OFFLINE"
                        color: root.online ? root.accentSoft : root.dangerColor
                        font.pixelSize: 10
                        font.family: root.panelFont
                        Behavior on color {
                            ColorAnimation {
                                duration: 300
                            }
                        }
                    }

                    Text {
                        text: "PATTERN: BLUE"
                        color: root.infoColor
                        font.pixelSize: 10
                        font.family: root.panelFont
                    }
                }
            }
        }

        // ---- CENTER: Planet Workspace Switcher ----------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            Repeater {
                model: planetModel

                delegate: Rectangle {
                    id: wsDelegate
                    width: 36
                    height: 36
                    color: "transparent"
                    border.width: 1
                    border.color: "transparent"
                    antialiasing: true

                    property bool isActive: (index === root.currentWorkspaceIndex)
                    property bool isHovered: wsMouseArea.containsMouse

                    Text {
                        text: model.symbol
                        anchors.centerIn: parent
                        font.pixelSize: 18
                        font.bold: wsDelegate.isActive
                        font.family: root.panelFont
                        color: wsDelegate.isActive ? model.color : (wsDelegate.isHovered ? root.accentSoft : root.textDim)
                        opacity: wsDelegate.isActive ? 1.0 : 0.7

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    // Active state indicator
                    Rectangle {
                        id: activeIndicator
                        width: parent.width - 10
                        height: 3
                        color: model.color
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 2
                        scale: wsDelegate.isActive ? 1.0 : 0.0
                        opacity: wsDelegate.isActive ? 0.8 : 0.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }

                    // Hover background
                    Rectangle {
                        id: hoverBg
                        anchors.fill: parent
                        color: root.accentColor
                        opacity: 0.0
                        radius: 4

                        states: [
                            State {
                                name: "hovered"
                                when: wsDelegate.isHovered && !wsDelegate.isActive
                                PropertyChanges {
                                    target: hoverBg
                                    opacity: 0.1
                                }
                            }
                        ]

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }
                    }

                    MouseArea {
                        id: wsMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            const newWorkspaceNum = index + 1; // 1-indexed
                            Hyprland.dispatch("workspace " + newWorkspaceNum);
                        }
                    }
                }
            }
        }

        // ---- RIGHT: Clock + Notifications + Tray + Battery + Net ----------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 10

            // Vertical Separator
            Item {
                width: 1
                height: 18
                Loader {
                    sourceComponent: separator
                }
            }

            // ---- Clock -----------------------------------------------------
            Text {
                id: clock
                color: root.textPrimary
                font.bold: true
                font.pixelSize: 14
                font.family: root.panelFont
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
            }

            // Vertical Separator
            Item {
                width: 1
                height: 18
                Loader {
                    sourceComponent: separator
                }
            }

            // ---- Notifications button (swaync-client -t) ------------------
            Rectangle {
                id: notifButton
                width: 26
                height: 24
                radius: 4
                border.width: 1
                border.color: root.accentSoft
                color: hoverAreaNotif.containsMouse ? "#0b1625" : "#050a12"
                antialiasing: true

                Text {
                    anchors.centerIn: parent
                    text: "🔔"              // swap to NF icon if you want
                    font.pixelSize: 14
                    color: root.accentColor
                    opacity: hoverAreaNotif.containsMouse ? 1.0 : 0.85
                }

                MouseArea {
                    id: hoverAreaNotif
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: swayncToggleProc.running = true
                }
            }

            Process {
                id: swayncToggleProc
                command: ["bash", "-c", "swaync-client -t"]
            }

            // ---- System Tray ----------------------------------------------
            Item {
                id: trayRoot
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 24

                RowLayout {
                    id: trayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items   // list<SystemTrayItem>

                        delegate: Item {
                            id: trayItemDelegate
                            width: 22
                            height: 22

                            readonly property var trayItem: modelData

                            // --- Drag & Drop (source) --------------------------------------------
                            Drag.dragType: Drag.Automatic
                            Drag.active: dragHandler.active
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            Drag.mimeData: ({
                                    "text/plain": trayItem.title,
                                    "application/x-quickshell-tray-id": trayItem.id
                                })

                            // --- Background + icon -----------------------------------------------
                            Rectangle {
                                id: trayBg
                                anchors.fill: parent
                                radius: 4
                                color: (hoverHandler.hovered || dropArea.containsDrag) ? "#0b1625" : "transparent"
                                border.width: (hoverHandler.hovered || dropArea.containsDrag) ? 1 : 0
                                border.color: root.accentSoft
                                antialiasing: true
                            }

                            IconImage {
                                anchors.fill: parent
                                anchors.margins: 3
                                source: trayItem.icon
                                smooth: true
                            }

                            // --- Drop target (DnD into tray) -------------------------------------
                            DropArea {
                                id: dropArea
                                anchors.fill: parent
                                onDropped: function (drop) {
                                    console.log("Dropped on tray item:", trayItem.title, drop.mimeData);
                                    drop.acceptProposedAction();
                                }
                            }

                            // --- Hover highlight (works for mouse + touchpad pointer) ------------
                            HoverHandler {
                                id: hoverHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            }

                            // --- LEFT CLICK (activate) -------------------------------------------
                            TapHandler {
                                id: leftTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.LeftButton
                                gesturePolicy: TapHandler.DragThreshold

                                onTapped: point => {
                                    // If a context/right tap also fires, let that win
                                    if (rightTap.active || contextTap.active)
                                        return;

                                    if (trayItem.onlyMenu && trayItem.hasMenu) {
                                        const pt = trayItemDelegate.mapToItem(root, width / 2, height);
                                        trayItem.display(root, Math.round(pt.x), Math.round(pt.y));
                                    } else {
                                        trayItem.activate();
                                    }
                                }

                                // Double-tap left: stronger "activate"
                                onDoubleTapped: point => {
                                    if (!trayItem.onlyMenu)
                                        trayItem.activate();
                                }
                            }

                            // --- RIGHT CLICK / two-finger tap (context) --------------------------
                            TapHandler {
                                id: rightTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.RightButton
                                gesturePolicy: TapHandler.DragThreshold

                                onTapped: point => {
                                    if (!trayItem.hasMenu) {
                                        // Fallback: treat as secondaryActivate if no menu
                                        trayItem.secondaryActivate();
                                        return;
                                    }

                                    const pt = trayItemDelegate.mapToItem(root, width / 2, height);
                                    trayItem.display(root, Math.round(pt.x), Math.round(pt.y));
                                }
                            }

                            // --- Long press → context menu (fallback for touchpads) --------------
                            TapHandler {
                                id: contextTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                // Long press threshold in ms
                                longPressThreshold: 400
                                gesturePolicy: TapHandler.WithinBounds

                                onLongPressed: point => {
                                    if (trayItem.hasMenu) {
                                        const pt = trayItemDelegate.mapToItem(root, width / 2, height);
                                        trayItem.display(root, Math.round(pt.x), Math.round(pt.y));
                                    }
                                }
                            }

                            // --- MIDDLE CLICK (secondary activate) -------------------------------
                            TapHandler {
                                id: middleTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.MiddleButton
                                gesturePolicy: TapHandler.DragThreshold

                                onTapped: point => trayItem.secondaryActivate()
                            }

                            // --- WHEEL (scroll actions – volume, brightness, etc.) ---------------
                            WheelHandler {
                                id: wheelHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                onWheel: wheel => {
                                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                    const horizontal = (wheel.angleDelta.y === 0);
                                    trayItem.scroll(delta, horizontal);
                                    wheel.accepted = true;
                                }
                            }

                            // --- Drag gesture (for QML Drag, but does not move icon) -------------
                            DragHandler {
                                id: dragHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                target: null             // keep the tray icon fixed in place
                                grabPermissions: PointerHandler.CanTakeOverFromAnything
                            }
                        }
                    }
                }
            }

            // ---- Battery Indicator (UPower) -------------------------------
            Item {
                id: batteryRoot
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 24
                implicitWidth: 70

                // Convenience properties
                property var dev: UPower.displayDevice
                property real percentage: dev.ready ? dev.percentage : -1
                property bool hasBattery: dev.ready && dev.isLaptopBattery && dev.isPresent

                property string batteryIcon: {
                    if (!hasBattery)
                        return "O";    // fallback / no battery icon
                    const p = percentage;
                    if (p <= .10)
                        return "~";
                    if (p <= .25)
                        return "+";
                    if (p <= .50)
                        return "*";
                    if (p <= .75)
                        return "@";
                    return "%";
                }

                property color batteryColor: {
                    if (!hasBattery)
                        return root.textDim;
                    if (percentage <= .10)
                        return root.dangerColor;
                    if (percentage <= .25)
                        return root.warningColor;
                    return root.accentSoft;
                }

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Icon (requires Nerd Font or similar; replace to taste)
                    Text {
                        text: batteryRoot.batteryIcon
                        visible: batteryRoot.hasBattery
                        color: batteryRoot.batteryColor
                        font.pixelSize: 14
                        font.family: root.panelFont
                        opacity: 0.95
                    }

                    Text {
                        text: batteryRoot.hasBattery && batteryRoot.percentage >= 0 ? Math.round(batteryRoot.percentage * 100) + "%" : "AC"
                        color: batteryRoot.batteryColor
                        font.pixelSize: 11
                        font.family: root.panelFont
                    }
                }
            }

            // Vertical Separator
            Item {
                width: 1
                height: 18
                Loader {
                    sourceComponent: separator
                }
            }

            // ---- Location + Network Hover Panel ---------------------------
            Item {
                id: netInfoRoot
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 260
                Layout.minimumWidth: 220
                implicitHeight: root.height

                RowLayout {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    spacing: 8

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.online ? root.accentColor : root.dangerColor
                        Behavior on color {
                            ColorAnimation {
                                duration: 300
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: -2

                        Text {
                            id: locationText
                            text: root.geoLocation
                            color: root.textPrimary
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.panelFont
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.online ? "LINK: " + root.publicIp : "LINK: DISCONNECTED"
                            color: root.textDim
                            font.pixelSize: 10
                            font.family: root.panelFont
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 20
                        radius: 1
                        color: root.textDim
                    }

                    ColumnLayout {
                        spacing: -2

                        Text {
                            id: twingateStatus
                            text: "TwinGate"
                            color: root.twingateConnected == "online" ? root.accentColor : root.dangerColor
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.panelFont
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            id: twingateText
                            text: root.twingateConnected
                            color: root.textDim
                            font.pixelSize: 10
                            font.family: root.panelFont
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Rectangle {
                    id: netPopup
                    opacity: hoverArea.containsMouse ? 0.98 : 0.0
                    anchors.top: netInfoRoot.bottom
                    anchors.right: netInfoRoot.right
                    anchors.topMargin: 4
                    width: 280
                    radius: 3
                    color: "#050a10"
                    border.color: root.accentSoft
                    border.width: 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: "NETWORK DIAGNOSTICS"
                            color: root.warningColor
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.panelFont
                            font.letterSpacing: 1
                        }

                        Rectangle {
                            height: 1
                            color: "#1b2735"
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "STATUS: " + (root.online ? "ONLINE" : "OFFLINE")
                            color: root.online ? root.accentColor : root.dangerColor
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }
                        Text {
                            text: "LOCAL IP: " + root.localIp
                            color: root.textPrimary
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }
                        Text {
                            text: "SUBNET: " + root.subnet
                            color: root.textPrimary
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }
                        Text {
                            text: "PUBLIC IP: " + root.publicIp
                            color: root.textPrimary
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }

                        Rectangle {
                            height: 1
                            color: "#1b2735"
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "SYSTEM GEO-VECTOR: " + root.geoLocation
                            color: root.textDim
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }
                    }
                }
            }
        }
    }

    // ================== GEOLOCATION VIA IP-API ============================
    Process {
        id: geoProc
        command: ["bash", "-c", "curl -s http://ip-api.com/json | jq -r '.countryCode + \", \" + .city'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.geoLocation = (t.length > 0 && t !== "null, null") ? t : "LOCATION: UNKNOWN";
            }
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: geoProc.running = true
    }

    // ================== NETWORK INFO + ONLINE STATE =======================
    Process {
        id: netProc
        command: ["bash", "-c", "local_ip=$(hostname -I 2>/dev/null | awk '{print $1}') ; " + "subnet=$(ip -o -f inet addr show 2>/dev/null | awk '/scope global/ {print $4; exit}') ; " + "pub=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || echo OFFLINE) ; " + "tg=$(twingate status);" + "echo \"$local_ip|$subnet|$pub|$tg\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");

                if (parts.length >= 4) {
                    root.localIp = parts[0] || "0.0.0.0";
                    root.subnet = parts[1] || "0.0.0.0/0";
                    root.publicIp = parts[2] || "UNKNOWN";
                    root.twingateConnected = parts[3];
                }

                root.online = (root.publicIp !== "OFFLINE" && root.publicIp !== "" && root.publicIp !== "UNKNOWN");
            }
        }
    }

    Timer {
        interval: 30 * 1000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }
}
