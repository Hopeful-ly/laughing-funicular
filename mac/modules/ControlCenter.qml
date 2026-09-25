import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs.services
import qs.widgets

// Control Center (top-right). Pages: main · wifi · bluetooth · sound
// Keys: Esc back/close · W Wi-Fi · B Bluetooth · S Sound · D Focus · A Keep Awake · ↑/↓ volume · M mute · Space play/pause
PopupLayer {
    id: cc
    ns: "mac-panel"
    persistent: true
    panelItem: panel
    readonly property string sname: screen ? screen.name : ""
    open: Shell.isOpen("controlcenter", sname)
    onDismissed: { if (page !== "main") page = "main"; else Shell.close(); }

    property string page: "main"
    property string hoverInfo: ""
    onOpenChanged: {
        if (open) { page = "main"; Net.refresh(); Brightness.refresh(); focusItem.forceActiveFocus(); }
    }
    onPageChanged: {
        if (page === "wifi") Net.scan();
        if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = page === "bluetooth";
        focusItem.forceActiveFocus();
    }

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt ? bt.enabled : false
    readonly property var btConnected: bt ? bt.devices.values.filter(d => d.connected) : []

    Item {
        id: focusItem
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (cc.typing) return;
            switch (e.key) {
            case Qt.Key_Escape: cc.dismissed(); break;
            case Qt.Key_W: cc.page = cc.page === "wifi" ? "main" : "wifi"; break;
            case Qt.Key_B: cc.page = cc.page === "bluetooth" ? "main" : "bluetooth"; break;
            case Qt.Key_S: cc.page = cc.page === "sound" ? "main" : "sound"; break;
            case Qt.Key_D: Config.dnd = !Config.dnd; break;
            case Qt.Key_A: Config.keepAwake = !Config.keepAwake; break;
            case Qt.Key_Up: Audio.setVolume(Audio.volume + 0.05); break;
            case Qt.Key_Down: Audio.setVolume(Audio.volume - 0.05); break;
            case Qt.Key_M: Audio.toggleMute(); break;
            case Qt.Key_Space: if (Media.player) Media.player.togglePlaying(); break;
            default: return;
            }
            e.accepted = true;
        }
    }

    Glass {
        id: panel
        readonly property int u: 64
        readonly property int g: 12
        width: u * 4 + g * 3 + 28
        height: content.implicitHeight + 28
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6 - (1 - cc.t) * 8
        radius: 30
        opacity: cc.t
        scale: 0.97 + 0.03 * cc.t
        transformOrigin: Item.TopRight
        Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        clip: true

        ColumnLayout {
            id: content
            x: 14; y: 14
            width: panel.width - 28
            spacing: panel.g

            // ================= MAIN PAGE =================
            // Rows 1–2: Wi-Fi pill, Bluetooth + Tailscale circles | Now Playing
            RowLayout {
                visible: cc.page === "main"
                spacing: panel.g
                ColumnLayout {
                    spacing: panel.g
                    CCTile {
                        Layout.preferredWidth: panel.u * 2 + panel.g
                        Layout.preferredHeight: panel.u
                        interactive: true
                        onClicked: cc.page = "wifi"
                        onHoveredChanged: cc.hoverInfo = hovered ? "Wi-Fi · click for networks · W" : ""
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 10
                            CCCircle {
                                diameter: 44
                                icon: Net.icon()
                                on: Net.wifiEnabled
                                onClicked: Net.setWifi(!Net.wifiEnabled)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                T { Layout.fillWidth: true; text: "Wi-Fi"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                T { Layout.fillWidth: true; text: !Net.wifiEnabled ? "Off" : Net.ssid || (Net.wired ? "Ethernet" : "Not Connected"); font.pixelSize: 11; color: Theme.text2 }
                            }
                        }
                    }
                    RowLayout {
                        spacing: panel.g
                        CCCircle {
                            icon: "bluetooth"
                            on: cc.btOn
                            onClicked: cc.page = "bluetooth"
                            onRightClicked: if (cc.bt) cc.bt.enabled = !cc.bt.enabled
                            onHoveredChanged: cc.hoverInfo = hovered ? "Bluetooth · " + (!cc.btOn ? "Off" : cc.btConnected.length ? cc.btConnected.map(d => d.name).join(", ") : "On") + " · right-click toggles" : ""
                        }
                        CCCircle {
                            icon: "vpn_lock"
                            on: Net.tsUp
                            onClicked: Net.toggleTailscale()
                            onHoveredChanged: cc.hoverInfo = hovered ? "Tailscale · " + (Net.tsState === "" ? "Unavailable" : Net.tsUp ? "Connected" : "Disconnected") : ""
                        }
                    }
                }

                // Now Playing
                CCTile {
                    Layout.preferredWidth: panel.u * 2 + panel.g
                    Layout.preferredHeight: panel.u * 2 + panel.g
                    radius: 26
                    Timer { interval: 1000; running: cc.open && Media.active && Media.player.isPlaying && Media.player.positionSupported; repeat: true; onTriggered: Media.player.positionChanged() }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 4
                        ClippingRectangle {
                            Layout.preferredWidth: 46; Layout.preferredHeight: 46
                            radius: 9
                            color: Theme.field
                            Image {
                                anchors.fill: parent
                                source: Media.player ? Media.player.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(96, 96)
                            }
                            Sym { visible: !Media.player || !Media.player.trackArtUrl; anchors.centerIn: parent; name: "music_note"; filled: true; size: 22; color: Theme.text3 }
                        }
                        Item { Layout.fillHeight: true }
                        T { Layout.fillWidth: true; text: Media.active ? Media.player.trackTitle : "Not Playing"; font.pixelSize: 13; font.weight: Font.DemiBold; color: Media.active ? Theme.text : Theme.text2 }
                        T { Layout.fillWidth: true; visible: Media.active; text: Media.active ? (Media.player.trackArtist || Media.player.identity) : ""; font.pixelSize: 11; color: Theme.text2 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            opacity: Media.active ? 1 : 0.35
                            Repeater {
                                model: [
                                    { icon: "fast_rewind", fn: () => Media.player.previous(), en: Media.active && Media.player.canGoPrevious },
                                    { icon: Media.active && Media.player.isPlaying ? "pause" : "play_arrow", fn: () => Media.player.togglePlaying(), en: Media.active && Media.player.canTogglePlaying },
                                    { icon: "fast_forward", fn: () => Media.player.next(), en: Media.active && Media.player.canGoNext }
                                ]
                                Hoverable {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 30; radius: 15
                                    Sym { anchors.centerIn: parent; name: modelData.icon; filled: true; size: 24 }
                                    onClicked: if (modelData.en) modelData.fn()
                                }
                            }
                        }
                    }
                }
            }

            // Row 3: Focus pill + Keep Awake + Appearance
            RowLayout {
                visible: cc.page === "main"
                spacing: panel.g
                CCTile {
                    Layout.preferredWidth: panel.u * 2 + panel.g
                    Layout.preferredHeight: panel.u
                    interactive: true
                    onClicked: Config.dnd = !Config.dnd
                    onHoveredChanged: cc.hoverInfo = hovered ? "Do Not Disturb · D" : ""
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 12
                        spacing: 10
                        CCCircle { diameter: 44; icon: "dark_mode"; on: Config.dnd; onClicked: Config.dnd = !Config.dnd }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            T { Layout.fillWidth: true; text: "Focus"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            T { Layout.fillWidth: true; text: Config.dnd ? "Do Not Disturb" : "Off"; font.pixelSize: 11; color: Theme.text2 }
                        }
                    }
                }
                CCCircle {
                    icon: "coffee"
                    on: Config.keepAwake
                    onClicked: Config.keepAwake = !Config.keepAwake
                    onHoveredChanged: cc.hoverInfo = hovered ? "Keep Awake · " + (Config.keepAwake ? "On — no auto-lock or sleep" : "Off") + " · A" : ""
                }
                CCCircle {
                    icon: Config.appearance === "auto" ? "brightness_auto" : Config.appearance === "dark" ? "dark_mode" : "light_mode"
                    on: Config.appearance !== "auto"
                    onClicked: Config.appearance = Config.appearance === "auto" ? "dark" : Config.appearance === "dark" ? "light" : "auto"
                    onHoveredChanged: cc.hoverInfo = hovered ? "Appearance · " + (Config.appearance === "auto" ? "Auto (follows wallpaper)" : Config.appearance === "dark" ? "Dark" : "Light") : ""
                }
            }

            // Row 4: Display
            CCTile {
                visible: cc.page === "main" && Brightness.available
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    anchors.topMargin: 12; anchors.bottomMargin: 12
                    spacing: 6
                    T { text: "Display"; font.pixelSize: 13; font.weight: Font.DemiBold }
                    KnobSlider {
                        Layout.fillWidth: true
                        iconLow: "brightness_low"; iconHigh: "brightness_high"
                        value: Brightness.value
                        onMoved: v => Brightness.set(Math.max(0.02, v))
                    }
                }
            }

            // Row 5: Sound (+ output picker)
            CCTile {
                visible: cc.page === "main"
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 12
                    anchors.topMargin: 12; anchors.bottomMargin: 12
                    spacing: 6
                    T { text: "Sound"; font.pixelSize: 13; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        KnobSlider {
                            Layout.fillWidth: true
                            iconLow: Audio.muted ? "volume_off" : "volume_mute"; iconHigh: "volume_up"
                            value: Audio.muted ? 0 : Audio.volume
                            onMoved: v => Audio.setVolume(v)
                        }
                        CCCircle {
                            diameter: 26; iconScale: 0.6
                            icon: "cast"
                            onClicked: cc.page = "sound"
                            onHoveredChanged: cc.hoverInfo = hovered ? "Output · " + Audio.nodeName(Audio.sink) + " · S" : ""
                        }
                    }
                }
            }

            // Row 6: quick actions
            RowLayout {
                visible: cc.page === "main"
                spacing: panel.g
                Repeater {
                    model: [
                        { icon: "screenshot_region", info: "Screenshot region · Super ⇧ S", fn: () => { Shell.close(); Shell.run("sleep 0.35; hyprshot -m region"); } },
                        { icon: "colorize", info: "Colour picker · Super `", fn: () => { Shell.close(); Shell.run("sleep 0.35; hyprpicker -a"); } },
                        { icon: "wallpaper", info: "Change wallpaper · Super ⇧ W", fn: () => Shell.openLauncher("wallpapers", cc.sname) },
                        { icon: "keyboard", info: "Keyboard shortcuts · Super /", fn: () => Shell.openLauncher("shortcuts", cc.sname) }
                    ]
                    CCCircle {
                        required property var modelData
                        icon: modelData.icon
                        onClicked: modelData.fn()
                        onHoveredChanged: cc.hoverInfo = hovered ? modelData.info : ""
                    }
                }
            }

            // ================= DETAIL PAGES =================
            RowLayout {
                visible: cc.page !== "main"
                Layout.fillWidth: true
                spacing: 6
                Hoverable {
                    implicitWidth: 26; implicitHeight: 26; radius: 13
                    Sym { anchors.centerIn: parent; name: "chevron_left"; size: 20 }
                    onClicked: cc.page = "main"
                }
                T {
                    Layout.fillWidth: true
                    text: cc.page === "wifi" ? "Wi-Fi" : cc.page === "bluetooth" ? "Bluetooth" : "Sound Output"
                    font.pixelSize: 15; font.weight: Font.Bold
                }
                Switch {
                    visible: cc.page === "wifi" || cc.page === "bluetooth"
                    checked: cc.page === "wifi" ? Net.wifiEnabled : cc.btOn
                    onToggled: v => { if (cc.page === "wifi") Net.setWifi(v); else if (cc.bt) cc.bt.enabled = v; }
                }
            }

            // Wi-Fi list
            ColumnLayout {
                visible: cc.page === "wifi"
                Layout.fillWidth: true
                spacing: 2
                T {
                    visible: Net.scanning && Net.networks.length === 0
                    text: "Searching…"; color: Theme.text2; font.pixelSize: 12
                    Layout.leftMargin: 6
                }
                T {
                    visible: Net.lastError !== ""
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    text: Net.lastError; color: Theme.systemRed; font.pixelSize: 11
                    wrapMode: Text.Wrap; maximumLineCount: 2
                }
                Repeater {
                    model: cc.page === "wifi" && Net.wifiEnabled ? Net.networks.slice(0, 12) : []
                    delegate: ColumnLayout {
                        id: netRow
                        required property var modelData
                        property bool askPw: false
                        Layout.fillWidth: true
                        spacing: 4
                        Hoverable {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 8
                                spacing: 9
                                Rectangle {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                    color: netRow.modelData.active ? Theme.accent : Theme.field
                                    Sym {
                                        anchors.centerIn: parent
                                        name: netRow.modelData.signal > 66 ? "wifi" : netRow.modelData.signal > 33 ? "wifi_2_bar" : "wifi_1_bar"
                                        filled: true; size: 15
                                        color: netRow.modelData.active ? Theme.accentText : Theme.text
                                    }
                                }
                                T { Layout.fillWidth: true; text: netRow.modelData.ssid; font.pixelSize: 13; font.weight: netRow.modelData.active ? Font.DemiBold : Font.Normal }
                                T { visible: Net.connecting === netRow.modelData.ssid; text: "Connecting…"; font.pixelSize: 11; color: Theme.text2 }
                                Sym { visible: netRow.modelData.secure; name: "lock"; size: 14; color: Theme.text3 }
                            }
                            onClicked: {
                                if (netRow.modelData.active) Net.disconnect();
                                else if (netRow.modelData.secure && !netRow.modelData.known) { netRow.askPw = true; cc.pwTarget = netRow.modelData.ssid; }
                                else Net.connect(netRow.modelData.ssid, "");
                            }
                        }
                        Rectangle {
                            visible: netRow.askPw && cc.pwTarget === netRow.modelData.ssid
                            Layout.fillWidth: true
                            Layout.leftMargin: 40
                            implicitHeight: 30
                            radius: 7
                            color: Theme.field
                            border.width: 1
                            border.color: pwFieldLocal.activeFocus ? Theme.accent : Theme.separator
                            TextInput {
                                id: pwFieldLocal
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.text
                                font.family: Config.fontFamily
                                font.pixelSize: 13
                                onVisibleChanged: if (visible) forceActiveFocus()
                                onActiveFocusChanged: cc.typing = activeFocus
                                onAccepted: { Net.connect(netRow.modelData.ssid, text); text = ""; netRow.askPw = false; focusItem.forceActiveFocus(); }
                                Keys.onEscapePressed: { netRow.askPw = false; focusItem.forceActiveFocus(); }
                                T { visible: parent.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Password  ·  ↵ join  ·  Esc cancel"; color: Theme.text3; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }

            // Bluetooth list
            ColumnLayout {
                visible: cc.page === "bluetooth"
                Layout.fillWidth: true
                spacing: 2
                T { visible: !cc.btOn; text: "Bluetooth is off."; color: Theme.text2; font.pixelSize: 12; Layout.leftMargin: 6 }
                Repeater {
                    model: cc.page === "bluetooth" && cc.btOn ? cc.bt.devices.values.filter(d => d.name).sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired)).slice(0, 12) : []
                    delegate: Hoverable {
                        id: btRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 34
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            spacing: 9
                            Rectangle {
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                color: btRow.modelData.connected ? Theme.accent : Theme.field
                                Sym {
                                    anchors.centerIn: parent
                                    name: (btRow.modelData.icon || "").indexOf("audio") >= 0 || (btRow.modelData.icon || "").indexOf("headset") >= 0 ? "headphones"
                                        : (btRow.modelData.icon || "").indexOf("phone") >= 0 ? "smartphone"
                                        : (btRow.modelData.icon || "").indexOf("mouse") >= 0 ? "mouse"
                                        : (btRow.modelData.icon || "").indexOf("keyboard") >= 0 ? "keyboard" : "bluetooth"
                                    filled: true; size: 15
                                    color: btRow.modelData.connected ? Theme.accentText : Theme.text
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                T { Layout.fillWidth: true; text: btRow.modelData.name; font.pixelSize: 13 }
                                T {
                                    visible: text !== ""
                                    text: btRow.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                                        : btRow.modelData.connected ? (btRow.modelData.batteryAvailable ? "Connected · " + Math.round(btRow.modelData.battery * 100) + "%" : "Connected")
                                        : btRow.modelData.paired ? "" : "Not paired"
                                    font.pixelSize: 11; color: Theme.text2
                                }
                            }
                        }
                        onClicked: {
                            const d = btRow.modelData;
                            if (d.connected) d.disconnect();
                            else if (!d.paired) d.pair();
                            else d.connect();
                        }
                    }
                }
            }

            // Sound outputs
            ColumnLayout {
                visible: cc.page === "sound"
                Layout.fillWidth: true
                spacing: 2
                Slider {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    icon: Audio.icon()
                    value: Audio.muted ? 0 : Audio.volume
                    onMoved: v => Audio.setVolume(v)
                }
                Repeater {
                    model: cc.page === "sound" ? Audio.sinks : []
                    delegate: Hoverable {
                        id: sinkRow
                        required property var modelData
                        readonly property bool current: Audio.sink && Audio.sink.id === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 34
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 8
                            spacing: 9
                            Rectangle {
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                color: sinkRow.current ? Theme.accent : Theme.field
                                Sym {
                                    anchors.centerIn: parent
                                    name: Audio.nodeName(sinkRow.modelData).toLowerCase().indexOf("headphone") >= 0 ? "headphones" : Audio.nodeName(sinkRow.modelData).toLowerCase().indexOf("hdmi") >= 0 ? "tv" : "speaker"
                                    filled: true; size: 15
                                    color: sinkRow.current ? Theme.accentText : Theme.text
                                }
                            }
                            T { Layout.fillWidth: true; text: Audio.nodeName(sinkRow.modelData); font.pixelSize: 13 }
                        }
                        onClicked: Audio.setSink(sinkRow.modelData)
                    }
                }
            }

            // Settings link for detail pages
            Rectangle { visible: cc.page !== "main"; Layout.fillWidth: true; height: 1; color: Theme.separator }
            Hoverable {
                visible: cc.page !== "main"
                Layout.fillWidth: true
                implicitHeight: 28
                T {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: cc.page === "wifi" ? "Wi-Fi Settings…" : cc.page === "bluetooth" ? "Bluetooth Settings…" : "Sound Settings…"
                    font.pixelSize: 13
                }
                onClicked: {
                    Shell.close();
                    Shell.run(cc.page === "wifi" ? "nm-connection-editor" : cc.page === "bluetooth" ? "blueman-manager" : "pavucontrol");
                }
            }

            // Footer: hover info, else keyboard hints
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                T {
                    anchors.centerIn: parent
                    visible: cc.hoverInfo !== "" && cc.page === "main"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cc.hoverInfo
                    font.pixelSize: 12
                    color: Theme.text2
                }
                Row {
                    anchors.centerIn: parent
                    visible: cc.hoverInfo === "" || cc.page !== "main"
                    spacing: 10
                    Hint { visible: cc.page !== "main"; label: "Back"; keys: ["Esc"] }
                    Hint { visible: cc.page === "main"; label: "Wi-Fi"; keys: ["W"] }
                    Hint { visible: cc.page === "main"; label: "Bluetooth"; keys: ["B"] }
                    Hint { visible: cc.page === "main"; label: "Sound"; keys: ["S"] }
                    Hint { visible: cc.page === "main"; label: "Focus"; keys: ["D"] }
                }
            }
        }
    }

    property string pwTarget: ""
    property bool typing: false
}
