//@ pragma UseQApplication
import Quickshell                    // PanelWindow, PopupWindow
import Quickshell.Io                 // Process, StdioCollector
import Quickshell.Hyprland           // Hyprland singleton
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower    // Battery info via UPower
import Quickshell.Services.Pipewire  // PipeWire audio
import Quickshell.Widgets            // IconImage
import QtQuick
import QtQuick.Layouts
import QtQml                         // ListModel, ListElement
import QtQuick.Effects               // MultiEffect (modern glow)

/*
 * NERV Celestial Monitoring System - Panel UI v3.0
 *
 * Overhaul: refined visuals, PopupWindow-based popups for
 * network diagnostics, clock/calendar, and battery details.
 */

PanelWindow {
    id: root
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 44
    color: "transparent"

    // --- NERV / MAGI STYLE THEME -------------------------------------------
    property color colorBackground: "#0c1220"
    property color colorBackgroundEnd: "#0a101f"
    property color accentColor: "#00ffaa"
    property color accentSoft: "#008f7a"
    property color warningColor: "#ff9900"
    property color dangerColor: "#ff3355"
    property color infoColor: "#55aaff"
    property color textDim: "#4a7a7a"
    property color textPrimary: "#e0f0f0"
    property color surfaceColor: "#0a1018"
    property color surfaceHover: "#0f1a28"
    property color borderColor: "#1a3040"
    property string panelFont: "monospace"

    // --- POPUP STATE -------------------------------------------------------
    property bool showNetPopup: false
    property bool showClockPopup: false
    property bool showBatteryPopup: false

    function closeAllPopups() {
        showNetPopup = false;
        showClockPopup = false;
        showBatteryPopup = false;
    }

    function togglePopup(which) {
        if (which === "net") {
            const was = showNetPopup;
            closeAllPopups();
            if (!was) {
                const pt = netInfoRoot.mapToItem(null, 0, 0);
                netPopupWindow.anchor.rect.x = pt.x + netInfoRoot.width - 320;
                showNetPopup = true;
            }
        } else if (which === "clock") {
            const was = showClockPopup;
            closeAllPopups();
            if (!was) {
                const pt = clockRoot.mapToItem(null, 0, 0);
                clockPopup.anchor.rect.x = pt.x + clockRoot.width / 2 - 160;
                showClockPopup = true;
            }
        } else if (which === "battery") {
            const was = showBatteryPopup;
            closeAllPopups();
            if (!was) {
                const pt = batteryRoot.mapToItem(null, 0, 0);
                batteryPopup.anchor.rect.x = pt.x + batteryRoot.width / 2 - 150;
                showBatteryPopup = true;
            }
        }
    }

    // --- SYSTEM STATE ------------------------------------------------------
    property string geoLocation: "ACQUIRING IP VECTOR..."
    property string localIp: "0.0.0.0"
    property string subnet: "0.0.0.0/0"
    property string publicIp: "UNKNOWN"
    property bool online: false
    property string tailscaleConnected: "..."
    property var audioSink: Pipewire.defaultAudioSink
    property var audioNode: audioSink ? audioSink.audio : null
    property int volumePercent: audioNode ? Math.round(audioNode.volume * 100) : 0
    property bool volumeMuted: audioNode ? audioNode.muted : false

    PwObjectTracker {
        objects: [root.audioSink]
    }

    // --- WORKSPACE STATE ---------------------------------------------------
    property int currentWorkspaceIndex: {
        const ws = Hyprland.focusedWorkspace;
        if (ws && ws.id > 0 && ws.id <= planetModel.count)
            return ws.id - 1;
        return -1;
    }

    // --- WORKSPACE DATA MODEL (Allomantic metals) ----------------------------
    ListModel {
        id: planetModel

        ListElement { name: "Steel";      symbol: "ST"; color: "#B0C4DE"; accent: "#8AA8C8"; glow: 0.25 }
        ListElement { name: "Iron";       symbol: "FE"; color: "#8B8B8B"; accent: "#6A6A6A"; glow: 0.18 }
        ListElement { name: "Pewter";     symbol: "PW"; color: "#A9A9A9"; accent: "#888888"; glow: 0.20 }
        ListElement { name: "Tin";        symbol: "TN"; color: "#E8E8E8"; accent: "#C0C0C0"; glow: 0.15 }
        ListElement { name: "Copper";     symbol: "CU"; color: "#CD7F32"; accent: "#B87333"; glow: 0.22 }
        ListElement { name: "Bronze";     symbol: "BZ"; color: "#C9956B"; accent: "#A67B5B"; glow: 0.20 }
        ListElement { name: "Zinc";       symbol: "ZN"; color: "#55AAFF"; accent: "#3388DD"; glow: 0.28 }
        ListElement { name: "Brass";      symbol: "BR"; color: "#FFD700"; accent: "#DAA520"; glow: 0.25 }
        ListElement { name: "Gold";       symbol: "AU"; color: "#FFB800"; accent: "#E5A600"; glow: 0.35 }
        ListElement { name: "Atium";      symbol: "AT"; color: "#C8A2FF"; accent: "#A77BDB"; glow: 0.40 }
    }

    // --- Reusable Components -----------------------------------------------
    Component {
        id: separator
        Rectangle {
            width: 1
            height: 20
            color: root.borderColor
            opacity: 0.6
        }
    }

    // --- BACKGROUND --------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.colorBackground }
            GradientStop { position: 1.0; color: root.colorBackgroundEnd }
        }
    }

    // Scanline overlay for sci-fi texture
    Canvas {
        anchors.fill: parent
        opacity: 0.03
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 0.5;
            for (let y = 0; y < height; y += 2) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
    }

    // Bottom accent glow line
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.3; color: root.accentSoft }
            GradientStop { position: 0.5; color: root.accentColor }
            GradientStop { position: 0.7; color: root.accentSoft }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: 0.5
    }

    // ====================== TOP BAR LAYOUT ================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 14

        // ---- LEFT: NERV Logo + System Title -------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            Item {
                id: logoWrapper
                width: 24
                height: 24

                Rectangle {
                    id: logoBg
                    anchors.fill: parent
                    radius: 4
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
                            ctx.moveTo(width / 2, 4);
                            ctx.lineTo(width - 4, height - 4);
                            ctx.lineTo(4, height - 4);
                            ctx.closePath();
                            ctx.lineWidth = 1.5;
                            ctx.strokeStyle = root.accentColor;
                            ctx.stroke();
                        }
                    }
                }

                // Glow effect with breathing pulse
                MultiEffect {
                    anchors.fill: logoBg
                    source: logoBg
                    shadowEnabled: true
                    shadowColor: root.accentColor
                    shadowOpacity: logoGlowAnim.glowVal
                    shadowBlur: 1.0
                    shadowScale: 1.5
                    blurEnabled: false
                    autoPaddingEnabled: true
                }

                // Breathing glow animation
                Item {
                    id: logoGlowAnim
                    property real glowVal: 0.5

                    SequentialAnimation on glowVal {
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.4; to: 0.9; duration: 1500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.9; to: 0.4; duration: 1500; easing.type: Easing.InOutSine }
                    }
                }
            }

            ColumnLayout {
                spacing: -1

                Text {
                    text: "NERV"
                    color: root.accentColor
                    font.bold: true
                    font.pixelSize: 15
                    font.family: root.panelFont
                    font.letterSpacing: 2
                }

                Text {
                    id: netStatusText
                    text: root.online ? "SYSTEM NOMINAL" : "LINK OFFLINE"
                    color: root.online ? root.accentSoft : root.dangerColor
                    font.pixelSize: 10
                    font.family: root.panelFont
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }

        // ---- CENTER: Planet Workspace Switcher ----------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Repeater {
                model: planetModel

                delegate: Item {
                    id: wsDelegate
                    width: 40
                    height: 40

                    property bool isActive: (index === root.currentWorkspaceIndex)
                    property bool isHovered: wsMouseArea.containsMouse

                    // Hover background
                    Rectangle {
                        id: hoverBg
                        anchors.fill: parent
                        color: root.accentColor
                        opacity: 0.0
                        radius: 6

                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        states: State {
                            name: "hovered"
                            when: wsDelegate.isHovered && !wsDelegate.isActive
                            PropertyChanges { target: hoverBg; opacity: 0.08 }
                        }
                    }

                    // Metal symbol
                    Text {
                        id: planetSymbol
                        text: model.symbol
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        font.pixelSize: 13
                        font.bold: true
                        font.family: root.panelFont
                        font.letterSpacing: 1
                        color: wsDelegate.isActive ? model.color : (wsDelegate.isHovered ? root.accentSoft : root.textDim)
                        opacity: wsDelegate.isActive ? 1.0 : 0.7
                        scale: wsDelegate.isActive ? 1.1 : (wsDelegate.isHovered ? 1.05 : 1.0)

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    // Active glow
                    MultiEffect {
                        anchors.fill: planetSymbol
                        source: planetSymbol
                        visible: wsDelegate.isActive
                        shadowEnabled: true
                        shadowColor: model.color
                        shadowOpacity: 0.6
                        shadowBlur: 0.8
                        shadowScale: 1.3
                        blurEnabled: false
                        autoPaddingEnabled: true
                    }

                    // Orbital dot indicator (replaces underline bar)
                    Rectangle {
                        id: orbitalDot
                        width: 5
                        height: 5
                        radius: 2.5
                        color: model.color
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        scale: wsDelegate.isActive ? 1.0 : 0.0
                        opacity: wsDelegate.isActive ? 0.9 : 0.0

                        Behavior on scale {
                            NumberAnimation { duration: 300; easing.type: Easing.OutBack }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 200 }
                        }
                    }

                    MouseArea {
                        id: wsMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        onClicked: Hyprland.dispatch("workspace " + (index + 1))
                    }
                }
            }
        }

        // ---- RIGHT: Clock + Notifications + Tray + Battery + Net ----------
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 10

            // Vertical Separator
            Item { width: 1; height: 20; Loader { sourceComponent: separator } }

            // ---- Clock (clickable for popup) --------------------------------
            Item {
                id: clockRoot
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockCol.implicitWidth + 12
                implicitHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: clockMouse.containsMouse ? root.surfaceHover : "transparent"
                    border.width: clockMouse.containsMouse ? 1 : 0
                    border.color: root.borderColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                ColumnLayout {
                    id: clockCol
                    anchors.centerIn: parent
                    spacing: -2

                    Text {
                        id: clockTime
                        color: root.textPrimary
                        font.bold: true
                        font.pixelSize: 15
                        font.family: root.panelFont
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(new Date(), "HH:mm:ss")
                    }

                    Text {
                        id: clockDate
                        color: root.textDim
                        font.pixelSize: 9
                        font.family: root.panelFont
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(new Date(), "ddd, MMM d")
                    }
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePopup("clock")
                }
            }

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    const now = new Date();
                    clockTime.text = Qt.formatDateTime(now, "HH:mm:ss");
                    clockDate.text = Qt.formatDateTime(now, "ddd, MMM d");
                }
            }

            // Vertical Separator
            Item { width: 1; height: 20; Loader { sourceComponent: separator } }

            // ---- Notifications button (swaync-client -t) ------------------
            Rectangle {
                id: notifButton
                width: 28
                height: 28
                radius: 6
                border.width: 1
                border.color: hoverAreaNotif.containsMouse ? root.accentSoft : root.borderColor
                color: hoverAreaNotif.containsMouse ? root.surfaceHover : "transparent"
                antialiasing: true

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                // Bell icon drawn with Canvas for reliable rendering
                Canvas {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    opacity: hoverAreaNotif.containsMouse ? 1.0 : 0.75
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = root.accentColor;
                        ctx.fillStyle = root.accentColor;
                        ctx.lineWidth = 1.2;
                        // Bell body
                        ctx.beginPath();
                        ctx.moveTo(3, 11);
                        ctx.quadraticCurveTo(3, 6, 5, 4);
                        ctx.quadraticCurveTo(8, 1.5, 11, 4);
                        ctx.quadraticCurveTo(13, 6, 13, 11);
                        ctx.lineTo(3, 11);
                        ctx.stroke();
                        // Brim
                        ctx.beginPath();
                        ctx.moveTo(1.5, 11);
                        ctx.lineTo(14.5, 11);
                        ctx.stroke();
                        // Clapper
                        ctx.beginPath();
                        ctx.arc(8, 13.5, 1.5, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                MouseArea {
                    id: hoverAreaNotif
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: swayncToggleProc.running = true
                }
            }

            Process {
                id: swayncToggleProc
                command: ["bash", "-c", "swaync-client -t"]
            }

            // ---- System Tray ----------------------------------------------
            Rectangle {
                id: trayRoot
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 28
                Layout.preferredWidth: 140
                color: "transparent"
                clip: true

                property bool hasOverflow: trayRow.implicitWidth > width
                property int overflowCount: {
                    if (!hasOverflow) return 0;
                    const itemWidth = 24 + 4;
                    const availableItems = Math.floor((width - 30) / itemWidth);
                    return Math.max(0, SystemTray.items.length - availableItems);
                }

                RowLayout {
                    id: trayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    anchors.left: parent.left

                    Repeater {
                        id: trayRepeater
                        model: SystemTray.items

                        delegate: Item {
                            id: trayItemDelegate
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 24
                            implicitHeight: 24

                            readonly property var trayItem: modelData
                            property var panelWindow: root

                            function showTrayMenu() {
                                if (!trayItem.hasMenu) return;
                                const w = panelWindow;
                                if (!w) return;
                                const pt = trayItemDelegate.mapToItem(null, width / 2, height);
                                trayItem.display(w, Math.round(pt.x), Math.round(pt.y));
                            }

                            Rectangle {
                                id: trayBg
                                anchors.fill: parent
                                radius: 5
                                color: (hoverHandler.hovered) ? root.surfaceHover : "transparent"
                                border.width: (hoverHandler.hovered) ? 1 : 0
                                border.color: root.borderColor
                                antialiasing: true
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 3
                                anchors.centerIn: parent

                                IconImage {
                                    id: trayIcon
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height)
                                    height: Math.min(parent.width, parent.height)
                                    source: {
                                        const iconSource = trayItem.icon;
                                        if (typeof iconSource === 'string' && iconSource.includes('?path='))
                                            return iconSource.split('?')[0];
                                        return iconSource;
                                    }
                                    smooth: true
                                }
                            }

                            HoverHandler {
                                id: hoverHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                id: unifiedTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                gesturePolicy: TapHandler.DragThreshold
                                longPressThreshold: 400

                                onTapped: function(point) {
                                    switch (point.button) {
                                    case Qt.LeftButton:
                                        if (trayItem.onlyMenu && trayItem.hasMenu)
                                            trayItemDelegate.showTrayMenu();
                                        else
                                            trayItem.activate();
                                        break;
                                    case Qt.MiddleButton:
                                        trayItem.secondaryActivate();
                                        break;
                                    case Qt.RightButton:
                                        if (trayItem.hasMenu)
                                            trayItemDelegate.showTrayMenu();
                                        else
                                            trayItem.secondaryActivate();
                                        break;
                                    }
                                }

                                onDoubleTapped: function(point) {
                                    if (point.button === Qt.LeftButton && !trayItem.onlyMenu)
                                        trayItem.activate();
                                }

                                onLongPressed: function(point) {
                                    if (trayItem.hasMenu)
                                        trayItemDelegate.showTrayMenu();
                                }
                            }

                            TapHandler {
                                id: contextTap
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                acceptedButtons: Qt.RightButton
                                gesturePolicy: TapHandler.DragThreshold

                                onTapped: function(point) {
                                    if (trayItem.hasMenu)
                                        trayItemDelegate.showTrayMenu();
                                    else
                                        trayItem.secondaryActivate();
                                }
                            }

                            WheelHandler {
                                id: wheelHandler
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: function(wheel) {
                                    const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                    const horizontal = (wheel.angleDelta.y === 0);
                                    trayItem.scroll(delta, horizontal);
                                    wheel.accepted = true;
                                }
                            }
                        }
                    }
                }

                // Overflow indicator
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 22
                    radius: 5
                    color: root.surfaceColor
                    border.width: 1
                    border.color: root.warningColor
                    visible: trayRoot.hasOverflow && trayRoot.overflowCount > 0
                    opacity: 0.95

                    Text {
                        anchors.centerIn: parent
                        text: "+" + trayRoot.overflowCount
                        color: root.warningColor
                        font.pixelSize: 10
                        font.bold: true
                        font.family: root.panelFont
                    }
                }
            }

            // Separator
            Item { width: 1; height: 20; Loader { sourceComponent: separator } }

            // ---- Volume Indicator ------------------------------------------------
            Item {
                id: volumeRoot
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 30
                implicitWidth: volumePill.implicitWidth

                property color volumeColor: root.volumeMuted ? root.dangerColor : root.accentSoft

                Rectangle {
                    id: volumePill
                    anchors.centerIn: parent
                    implicitWidth: volumeRow.implicitWidth + 14
                    implicitHeight: 26
                    radius: 6
                    color: volumeMouse.containsMouse ? root.surfaceHover : Qt.rgba(volumeRoot.volumeColor.r, volumeRoot.volumeColor.g, volumeRoot.volumeColor.b, 0.08)
                    border.width: 1
                    border.color: volumeMouse.containsMouse ? volumeRoot.volumeColor : root.borderColor
                    antialiasing: true

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: volumeRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            id: volumeIcon
                            text: root.volumeMuted ? "VOL" : "VOL"
                            color: volumeRoot.volumeColor
                            font.pixelSize: 10
                            font.family: root.panelFont
                        }

                        Text {
                            text: root.volumeMuted ? "MUTE" : root.volumePercent + "%"
                            color: volumeRoot.volumeColor
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.panelFont
                        }
                    }
                }

                MouseArea {
                    id: volumeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: function(mouse) {
                        if (root.audioNode)
                            root.audioNode.muted = !root.audioNode.muted;
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: function(wheel) {
                        if (!root.audioNode) return;
                        const step = 0.05;
                        const delta = wheel.angleDelta.y;
                        if (delta > 0)
                            root.audioNode.volume = Math.min(1.0, root.audioNode.volume + step);
                        else if (delta < 0)
                            root.audioNode.volume = Math.max(0.0, root.audioNode.volume - step);
                    }
                }
            }

            // Separator
            Item { width: 1; height: 20; Loader { sourceComponent: separator } }

            // ---- Battery Indicator (clickable for popup) --------------------
            Item {
                id: batteryRoot
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 30
                implicitWidth: batteryPill.implicitWidth

                property var dev: UPower.displayDevice
                property real percentage: dev.ready ? dev.percentage : -1
                property bool hasBattery: dev.ready && dev.isLaptopBattery && dev.isPresent
                property bool isCharging: dev.ready && (dev.state === UPowerDeviceState.Charging || dev.state === UPowerDeviceState.FullyCharged)

                property string batteryIcon: {
                    if (!hasBattery) return "AC";
                    const p = Math.max(0, Math.min(1, percentage));
                    const bars = ["\u26A0", "\u2582", "\u2583", "\u2584", "\u2585", "\u2586", "\u2587", "\u2588"];
                    return bars[Math.min(bars.length - 1, Math.floor(p * bars.length))];
                }

                property color batteryColor: {
                    if (!hasBattery) return root.textDim;
                    if (percentage <= .10) return root.dangerColor;
                    if (percentage <= .25) return root.warningColor;
                    return root.accentSoft;
                }

                // Color-coded background pill
                Rectangle {
                    id: batteryPill
                    anchors.centerIn: parent
                    implicitWidth: batteryRow.implicitWidth + 14
                    implicitHeight: 26
                    radius: 6
                    color: batteryMouse.containsMouse ? root.surfaceHover : Qt.rgba(batteryRoot.batteryColor.r, batteryRoot.batteryColor.g, batteryRoot.batteryColor.b, 0.08)
                    border.width: 1
                    border.color: batteryMouse.containsMouse ? batteryRoot.batteryColor : root.borderColor
                    antialiasing: true

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: batteryRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: batteryRoot.batteryIcon
                            visible: batteryRoot.hasBattery
                            color: batteryRoot.batteryColor
                            font.pixelSize: 14
                            font.family: root.panelFont
                        }

                        Text {
                            text: batteryRoot.hasBattery && batteryRoot.percentage >= 0 ? Math.round(batteryRoot.percentage * 100) + "%" : "AC"
                            color: batteryRoot.batteryColor
                            font.pixelSize: 11
                            font.bold: true
                            font.family: root.panelFont
                        }
                    }
                }

                MouseArea {
                    id: batteryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePopup("battery")
                }
            }

            // Separator
            Item { width: 1; height: 20; Loader { sourceComponent: separator } }

            // ---- Network Status (clickable for popup) -----------------------
            Item {
                id: netInfoRoot
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: netRow.implicitWidth + 12
                Layout.minimumWidth: 100
                implicitHeight: 36

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: netMouse.containsMouse ? root.surfaceHover : "transparent"
                    border.width: netMouse.containsMouse ? 1 : 0
                    border.color: root.borderColor
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                RowLayout {
                    id: netRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Status dot
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.online ? root.accentColor : root.dangerColor
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Text {
                        text: root.geoLocation
                        color: root.textPrimary
                        font.pixelSize: 11
                        font.bold: true
                        font.family: root.panelFont
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePopup("net")
                }
            }
        }
    }

    // ====================== POPUP WINDOWS ==================================

    // ---- Clock/Calendar Popup ---------------------------------------------
    PopupWindow {
        id: clockPopup
        anchor.window: root
        anchor.rect.x: 0
        anchor.rect.y: root.implicitHeight
        visible: root.showClockPopup
        width: 320
        height: clockPopupContent.implicitHeight + 2
        color: "transparent"

        Rectangle {
            id: clockPopupContent
            anchors.fill: parent
            anchors.margins: 1
            radius: 6
            color: root.surfaceColor
            border.width: 1
            border.color: root.accentSoft
            implicitHeight: clockPopupCol.implicitHeight + 24

            // Entry animation
            opacity: root.showClockPopup ? 1.0 : 0.0
            transform: Translate { y: root.showClockPopup ? 0 : -4 }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                id: clockPopupCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Header
                Text {
                    text: "TEMPORAL ANALYSIS"
                    color: root.warningColor
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.panelFont
                    font.letterSpacing: 1
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                // Large time
                Text {
                    id: popupTime
                    text: Qt.formatDateTime(new Date(), "HH:mm:ss")
                    color: root.accentColor
                    font.pixelSize: 32
                    font.bold: true
                    font.family: root.panelFont
                    font.letterSpacing: 2
                    Layout.alignment: Qt.AlignHCenter
                }

                // Full date
                Text {
                    id: popupDate
                    text: Qt.formatDateTime(new Date(), "dddd, MMMM d, yyyy")
                    color: root.textPrimary
                    font.pixelSize: 12
                    font.family: root.panelFont
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                // Day/week stats
                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4
                    Layout.fillWidth: true

                    Text { text: "DAY OF YEAR:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        id: popupDayOfYear
                        text: {
                            const now = new Date();
                            const start = new Date(now.getFullYear(), 0, 0);
                            const diff = now - start;
                            return Math.floor(diff / 86400000).toString();
                        }
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "WEEK OF YEAR:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        id: popupWeekOfYear
                        text: {
                            const now = new Date();
                            const start = new Date(now.getFullYear(), 0, 1);
                            const days = Math.floor((now - start) / 86400000);
                            return Math.ceil((days + start.getDay() + 1) / 7).toString();
                        }
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "UNIX EPOCH:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        id: popupEpoch
                        text: Math.floor(Date.now() / 1000).toString()
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }
                }
            }
        }

        // Update popup content each second when visible
        Timer {
            interval: 1000
            running: root.showClockPopup
            repeat: true
            onTriggered: {
                const now = new Date();
                popupTime.text = Qt.formatDateTime(now, "HH:mm:ss");
                popupDate.text = Qt.formatDateTime(now, "dddd, MMMM d, yyyy");
                popupEpoch.text = Math.floor(Date.now() / 1000).toString();
            }
        }
    }

    // ---- Battery Popup ----------------------------------------------------
    PopupWindow {
        id: batteryPopup
        anchor.window: root
        anchor.rect.x: 0
        anchor.rect.y: root.implicitHeight
        visible: root.showBatteryPopup
        width: 300
        height: batteryPopupContent.implicitHeight + 2
        color: "transparent"

        Rectangle {
            id: batteryPopupContent
            anchors.fill: parent
            anchors.margins: 1
            radius: 6
            color: root.surfaceColor
            border.width: 1
            border.color: root.accentSoft
            implicitHeight: batteryPopupCol.implicitHeight + 24

            opacity: root.showBatteryPopup ? 1.0 : 0.0
            transform: Translate { y: root.showBatteryPopup ? 0 : -4 }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                id: batteryPopupCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "POWER SYSTEMS"
                    color: root.warningColor
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.panelFont
                    font.letterSpacing: 1
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                // Large percentage
                Text {
                    text: batteryRoot.hasBattery ? Math.round(batteryRoot.percentage * 100) + "%" : "AC POWER"
                    color: batteryRoot.batteryColor
                    font.pixelSize: 28
                    font.bold: true
                    font.family: root.panelFont
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4
                    Layout.fillWidth: true

                    Text { text: "STATE:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: {
                            if (!batteryRoot.hasBattery) return "NO BATTERY";
                            if (!batteryRoot.dev.ready) return "UNKNOWN";
                            switch (batteryRoot.dev.state) {
                                case UPowerDeviceState.Charging: return "CHARGING";
                                case UPowerDeviceState.Discharging: return "DISCHARGING";
                                case UPowerDeviceState.FullyCharged: return "FULLY CHARGED";
                                case UPowerDeviceState.PendingCharge: return "PENDING CHARGE";
                                case UPowerDeviceState.PendingDischarge: return "PENDING DISCHARGE";
                                default: return "UNKNOWN";
                            }
                        }
                        color: batteryRoot.isCharging ? root.accentColor : root.textPrimary
                        font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "ENERGY:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: batteryRoot.dev.ready ? batteryRoot.dev.energy.toFixed(1) + " / " + batteryRoot.dev.energyFull.toFixed(1) + " Wh" : "N/A"
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "RATE:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: batteryRoot.dev.ready ? batteryRoot.dev.energyRate.toFixed(1) + " W" : "N/A"
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "HEALTH:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: batteryRoot.dev.ready && batteryRoot.dev.energyFullDesign > 0
                            ? Math.round(batteryRoot.dev.energyFull / batteryRoot.dev.energyFullDesign * 100) + "%"
                            : "N/A"
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }

                    Text { text: "TIME LEFT:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: {
                            if (!batteryRoot.dev.ready) return "N/A";
                            const secs = batteryRoot.dev.timeToEmpty;
                            if (secs <= 0) {
                                const secsFull = batteryRoot.dev.timeToFull;
                                if (secsFull <= 0) return "CALCULATING...";
                                const h = Math.floor(secsFull / 3600);
                                const m = Math.floor((secsFull % 3600) / 60);
                                return h + "h " + m + "m TO FULL";
                            }
                            const h = Math.floor(secs / 3600);
                            const m = Math.floor((secs % 3600) / 60);
                            return h + "h " + m + "m REMAINING";
                        }
                        color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont
                    }
                }
            }
        }
    }

    // ---- Network Diagnostics Popup ----------------------------------------
    PopupWindow {
        id: netPopupWindow
        anchor.window: root
        anchor.rect.x: 0
        anchor.rect.y: root.implicitHeight
        visible: root.showNetPopup
        width: 320
        height: netPopupContent.implicitHeight + 2
        color: "transparent"

        Rectangle {
            id: netPopupContent
            anchors.fill: parent
            anchors.margins: 1
            radius: 6
            color: root.surfaceColor
            border.width: 1
            border.color: root.accentSoft
            implicitHeight: netPopupCol.implicitHeight + 24

            opacity: root.showNetPopup ? 1.0 : 0.0
            transform: Translate { y: root.showNetPopup ? 0 : -4 }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            ColumnLayout {
                id: netPopupCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                Text {
                    text: "NETWORK DIAGNOSTICS"
                    color: root.warningColor
                    font.pixelSize: 11
                    font.bold: true
                    font.family: root.panelFont
                    font.letterSpacing: 1
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4
                    Layout.fillWidth: true

                    Text { text: "STATUS:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: root.online ? "ONLINE" : "OFFLINE"
                        color: root.online ? root.accentColor : root.dangerColor
                        font.pixelSize: 10; font.bold: true; font.family: root.panelFont
                    }

                    Text { text: "LOCAL IP:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text { text: root.localIp; color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont }

                    Text { text: "SUBNET:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text { text: root.subnet; color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont }

                    Text { text: "PUBLIC IP:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text { text: root.publicIp; color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont }

                    Text { text: "GEO-VECTOR:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text { text: root.geoLocation; color: root.textPrimary; font.pixelSize: 10; font.family: root.panelFont }
                }

                Rectangle { height: 1; color: root.borderColor; Layout.fillWidth: true }

                // Tailscale section
                Text {
                    text: "TAILSCALE"
                    color: root.warningColor
                    font.pixelSize: 10
                    font.bold: true
                    font.family: root.panelFont
                    font.letterSpacing: 1
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4
                    Layout.fillWidth: true

                    Text { text: "STATE:"; color: root.textDim; font.pixelSize: 10; font.family: root.panelFont }
                    Text {
                        text: root.tailscaleConnected.toUpperCase()
                        color: root.tailscaleConnected.toLowerCase() === "running" ? root.accentColor : root.dangerColor
                        font.pixelSize: 10; font.bold: true; font.family: root.panelFont
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
        command: ["bash", "-c", "local_ip=$(hostname -I 2>/dev/null | awk '{print $1}') ; " +
            "subnet=$(ip -o -f inet addr show 2>/dev/null | awk '/scope global/ {print $4; exit}') ; " +
            "pub=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || echo OFFLINE) ; " +
            "ts=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // \"unknown\"' 2>/dev/null || echo unknown);" +
            "echo \"$local_ip|$subnet|$pub|$ts\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("|");
                if (parts.length >= 4) {
                    root.localIp = parts[0] || "0.0.0.0";
                    root.subnet = parts[1] || "0.0.0.0/0";
                    root.publicIp = parts[2] || "UNKNOWN";
                    root.tailscaleConnected = parts[3] || "unknown";
                }
                root.online = (root.publicIp !== "OFFLINE" && root.publicIp !== "" && root.publicIp !== "UNKNOWN");
            }
        }
    }

    Timer {
        interval: root.tailscaleConnected.toLowerCase() === "running" ? 2 * 60 * 1000 : 2 * 1000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }

}
