import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs.services
import qs.widgets

// Control Center (top-right). Pages: main · wifi · bluetooth · tailscale · sound
// Keys: Esc back/close · W Wi-Fi · B Bluetooth · T Tailscale · S Sound · D Focus · A Keep Awake · ↑/↓ volume · M mute · Space play/pause
// Tailscale page: 1–9 switch account · N add account · C connect/disconnect
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
        if (open) { page = Shell.ccPage; Shell.ccPage = "main"; Net.refresh(); Brightness.refresh(); focusItem.forceActiveFocus(); }
    }
    onPageChanged: {
        if (page === "wifi") Net.scan();
        if (page === "tailscale") Tailscale.refresh();
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
            if (cc.page === "tailscale") {
                const n = e.key - Qt.Key_1;
                if (n >= 0 && n < 9 && n < Tailscale.accounts.length) { Tailscale.switchTo(Tailscale.accounts[n].id); e.accepted = true; return; }
                if (e.key === Qt.Key_N) { Tailscale.addAccount(); e.accepted = true; return; }
                if (e.key === Qt.Key_C) { Tailscale.toggle(); e.accepted = true; return; }
            }
            switch (e.key) {
            case Qt.Key_Escape: cc.dismissed(); break;
            case Qt.Key_W: cc.page = cc.page === "wifi" ? "main" : "wifi"; break;
            case Qt.Key_B: cc.page = cc.page === "bluetooth" ? "main" : "bluetooth"; break;
            case Qt.Key_T: cc.page = cc.page === "tailscale" ? "main" : "tailscale"; break;
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
                            on: Tailscale.up
                            onClicked: cc.page = "tailscale"
                            onRightClicked: Tailscale.toggle()
                            onHoveredChanged: cc.hoverInfo = hovered ? "Tailscale · " + Tailscale.stateText() + (Tailscale.current ? " · " + Tailscale.label(Tailscale.current) : "") + " · T" : ""
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
                    text: cc.page === "wifi" ? "Wi-Fi" : cc.page === "bluetooth" ? "Bluetooth" : cc.page === "tailscale" ? "Tailscale" : "Sound Output"
                    font.pixelSize: 15; font.weight: Font.Bold
                }
                Switch {
                    visible: cc.page === "wifi" || cc.page === "bluetooth" || (cc.page === "tailscale" && Tailscale.available)
                    checked: cc.page === "wifi" ? Net.wifiEnabled : cc.page === "tailscale" ? Tailscale.up : cc.btOn
                    onToggled: v => { if (cc.page === "wifi") Net.setWifi(v); else if (cc.page === "tailscale") Tailscale.setUp(v); else if (cc.bt) cc.bt.enabled = v; }
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

            // Tailscale: this device · accounts · exit node · devices · options
            ColumnLayout {
                visible: cc.page === "tailscale"
                Layout.fillWidth: true
                spacing: 2

                // This device (click copies the Tailscale IP)
                Hoverable {
                    id: selfRow
                    Layout.fillWidth: true
                    implicitHeight: 40
                    onClicked: if (Tailscale.ip) cc.copy("self", Tailscale.ip)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        spacing: 9
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                            color: Tailscale.up ? Theme.accent : Theme.field
                            Sym { anchors.centerIn: parent; name: "vpn_lock"; filled: true; size: 15; color: Tailscale.up ? Theme.accentText : Theme.text }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            T { Layout.fillWidth: true; text: Tailscale.hostname || "This device"; font.pixelSize: 13; font.weight: Font.DemiBold }
                            T { Layout.fillWidth: true; text: Tailscale.busy ? Tailscale.busy + "…" : Tailscale.stateText() + (Tailscale.up && Tailscale.ip ? " · " + Tailscale.ip : ""); font.pixelSize: 11; color: Theme.text2 }
                        }
                        T { visible: selfRow.hovered && Tailscale.ip !== ""; text: cc.copied === "self" ? "Copied" : "Copy IP"; font.pixelSize: 11; color: Theme.text3 }
                    }
                }
                T {
                    visible: Tailscale.error !== ""
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    text: Tailscale.error; color: Theme.systemRed; font.pixelSize: 11
                    wrapMode: Text.Wrap; maximumLineCount: 3
                }
                Hoverable {
                    visible: Tailscale.denied
                    Layout.fillWidth: true
                    implicitHeight: grantText.implicitHeight + 12
                    onClicked: { Shell.close(); Quickshell.execDetached([Config.terminal, "--hold", "-e", "bash", "-c", "sudo tailscale set --operator=\"$USER\" && echo && echo 'Done — Tailscale can now be managed from the Control Center.'"]); }
                    T {
                        id: grantText
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.leftMargin: 6; anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Account switching needs operator access. Click to run <b>sudo tailscale set --operator=$USER</b>."
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        font.pixelSize: 11; color: Theme.systemOrange
                    }
                }

                // Accounts
                Section { visible: Tailscale.available; text: "Accounts" }
                Repeater {
                    model: cc.page === "tailscale" ? Tailscale.accounts : []
                    delegate: Hoverable {
                        id: acctRow
                        required property var modelData
                        required property int index
                        readonly property bool sel: modelData.selected
                        // The remove button sits above the row's MouseArea and takes its hover, so count both.
                        readonly property bool hot: hovered || removeBtn.hovered
                        Layout.fillWidth: true
                        implicitHeight: 40
                        onClicked: Tailscale.switchTo(modelData.id)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            spacing: 9
                            Rectangle {
                                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                                color: acctRow.sel ? Theme.accent : Theme.field
                                T {
                                    anchors.centerIn: parent
                                    text: Tailscale.label(acctRow.modelData).charAt(0).toUpperCase()
                                    font.pixelSize: 12; font.weight: Font.Bold
                                    color: acctRow.sel ? Theme.accentText : Theme.text
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                T { Layout.fillWidth: true; text: Tailscale.label(acctRow.modelData); font.pixelSize: 13; font.weight: acctRow.sel ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                                T { Layout.fillWidth: true; text: Tailscale.sublabel(acctRow.modelData); font.pixelSize: 11; color: Theme.text2; elide: Text.ElideMiddle }
                            }
                            // Hover: remove (or log out of the active account); otherwise index shortcut + check.
                            // Fixed width so swapping them doesn't shift the row under the cursor.
                            Item {
                                Layout.preferredWidth: 44
                                Layout.fillHeight: true
                                Row {
                                    visible: !acctRow.hot
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Kbd { anchors.verticalCenter: parent.verticalCenter; visible: acctRow.index < 9 && Tailscale.accounts.length > 1; keys: [String(acctRow.index + 1)] }
                                    Sym { anchors.verticalCenter: parent.verticalCenter; visible: acctRow.sel; name: "check"; size: 16; color: Theme.accent }
                                }
                                Hoverable {
                                    id: removeBtn
                                    visible: acctRow.hot
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24; height: 24; radius: 12
                                    Sym { anchors.centerIn: parent; name: acctRow.sel ? "logout" : "close"; size: 15; color: Theme.text2 }
                                    onClicked: {
                                        const a = acctRow.modelData;
                                        const name = Tailscale.label(a);
                                        Shell.close();
                                        if (a.selected) Shell.ask({ title: "Log out of “" + name + "”?", body: "This device leaves the tailnet until you sign in again.", icon: "logout", confirm: "Log Out", destructive: true, action: () => Tailscale.logout() });
                                        else Shell.ask({ title: "Remove “" + name + "”?", body: "You’ll need to sign in again to switch back to this account.", icon: "person_remove", confirm: "Remove", destructive: true, action: () => Tailscale.remove(a.id) });
                                    }
                                }
                            }
                        }
                    }
                }
                // Sign-in in progress
                RowLayout {
                    visible: Tailscale.signingIn
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 4
                    Layout.preferredHeight: 34
                    spacing: 9
                    Sym { name: "open_in_browser"; size: 18; color: Theme.text2; Layout.preferredWidth: 26 }
                    T { Layout.fillWidth: true; text: Tailscale.authUrl ? "Finish signing in in your browser" : "Starting sign-in…"; font.pixelSize: 12; color: Theme.text2; wrapMode: Text.Wrap }
                    Hoverable {
                        visible: Tailscale.authUrl !== ""
                        implicitWidth: openLbl.implicitWidth + 16; implicitHeight: 24; radius: 12
                        color: hovered ? Theme.tileHover : Theme.field
                        T { id: openLbl; anchors.centerIn: parent; text: "Open"; font.pixelSize: 11 }
                        onClicked: Tailscale.openAuthUrl()
                    }
                    Hoverable {
                        implicitWidth: cancelLbl.implicitWidth + 16; implicitHeight: 24; radius: 12
                        color: hovered ? Theme.tileHover : Theme.field
                        T { id: cancelLbl; anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 11 }
                        onClicked: Tailscale.cancelSignIn()
                    }
                }
                Hoverable {
                    id: addRow
                    visible: Tailscale.available && !Tailscale.signingIn
                    Layout.fillWidth: true
                    implicitHeight: 34
                    onClicked: Tailscale.addAccount()
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 6
                        spacing: 9
                        Rectangle {
                            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                            color: Theme.field
                            Sym { anchors.centerIn: parent; name: "add"; size: 16; color: Theme.text }
                        }
                        T { Layout.fillWidth: true; text: "Add Account…"; font.pixelSize: 13 }
                        Kbd { keys: ["N"] }
                    }
                }

                // Exit node
                Section { visible: Tailscale.up && Tailscale.exitNodes.length > 0; text: "Exit Node" }
                Repeater {
                    model: cc.page === "tailscale" && Tailscale.up && Tailscale.exitNodes.length ? [null].concat(Tailscale.exitNodes) : []
                    delegate: Hoverable {
                        id: exitRow
                        required property var modelData
                        readonly property bool sel: modelData ? modelData.exitActive : !Tailscale.exitNode
                        Layout.fillWidth: true
                        implicitHeight: 30
                        opacity: !modelData || modelData.online ? 1 : 0.5
                        onClicked: if (!sel) Tailscale.setExitNode(modelData ? modelData.ip : "")
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 9
                            Sym { name: exitRow.modelData ? "public" : "block"; size: 16; color: exitRow.sel ? Theme.accent : Theme.text2 }
                            T { Layout.fillWidth: true; text: exitRow.modelData ? exitRow.modelData.name : "None"; font.pixelSize: 13; font.weight: exitRow.sel ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
                            T { visible: !!exitRow.modelData && !exitRow.modelData.online; text: "Offline"; font.pixelSize: 11; color: Theme.text3 }
                            Sym { visible: exitRow.sel; name: "check"; size: 16; color: Theme.accent }
                        }
                    }
                }
                OptionRow {
                    visible: Tailscale.up && Tailscale.exitNode !== null
                    label: "Allow Local Network Access"
                    checked: !!Tailscale.prefs.ExitNodeAllowLANAccess
                    onToggled: v => Tailscale.setPref("exit-node-allow-lan-access", v)
                }

                // Devices on the tailnet (click copies MagicDNS name)
                Section {
                    visible: Tailscale.up && Tailscale.peers.length > 0
                    text: "Devices · " + Tailscale.peers.filter(p => p.online).length + " online"
                }
                Repeater {
                    model: cc.page === "tailscale" && Tailscale.up ? Tailscale.peers.slice(0, 6) : []
                    delegate: Hoverable {
                        id: peerRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        onClicked: cc.copy(modelData.id, modelData.dns || modelData.ip)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 9
                            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: peerRow.modelData.online ? Theme.systemGreen : Theme.text3 }
                            T { Layout.fillWidth: true; text: peerRow.modelData.name; font.pixelSize: 13; elide: Text.ElideRight; color: peerRow.modelData.online ? Theme.text : Theme.text2 }
                            T {
                                text: cc.copied === peerRow.modelData.id ? "Copied" : peerRow.hovered ? "Copy name" : peerRow.modelData.ip
                                font.pixelSize: 11; color: Theme.text3
                            }
                        }
                    }
                }
                T {
                    visible: Tailscale.up && Tailscale.peers.length > 6
                    Layout.leftMargin: 8
                    text: "+ " + (Tailscale.peers.length - 6) + " more in the admin console"
                    font.pixelSize: 11; color: Theme.text3
                }

                // Options
                Section { visible: Tailscale.available && !!Tailscale.current; text: "Options" }
                OptionRow {
                    visible: Tailscale.available && !!Tailscale.current
                    label: "Use Tailscale DNS"
                    checked: !!Tailscale.prefs.CorpDNS
                    onToggled: v => Tailscale.setPref("accept-dns", v)
                }
                OptionRow {
                    visible: Tailscale.available && !!Tailscale.current
                    label: "Accept Subnet Routes"
                    checked: !!Tailscale.prefs.RouteAll
                    onToggled: v => Tailscale.setPref("accept-routes", v)
                }
                OptionRow {
                    visible: Tailscale.available && !!Tailscale.current
                    label: "Block Incoming Connections"
                    checked: !!Tailscale.prefs.ShieldsUp
                    onToggled: v => Tailscale.setPref("shields-up", v)
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
                    text: cc.page === "wifi" ? "Wi-Fi Settings…" : cc.page === "bluetooth" ? "Bluetooth Settings…" : cc.page === "tailscale" ? "Tailscale Admin Console…" : "Sound Settings…"
                    font.pixelSize: 13
                }
                onClicked: {
                    Shell.close();
                    if (cc.page === "tailscale") return Tailscale.adminConsole();
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
                    Hint { visible: cc.page === "tailscale" && Tailscale.accounts.length > 1; label: "Switch"; keys: ["1–" + Math.min(9, Tailscale.accounts.length)] }
                    Hint { visible: cc.page === "tailscale"; label: "Add"; keys: ["N"] }
                    Hint { visible: cc.page === "tailscale" && Tailscale.available; label: Tailscale.up ? "Disconnect" : "Connect"; keys: ["C"] }
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
    property string copied: ""         // key of the row that just copied to the clipboard
    Timer { id: copiedReset; interval: 1400; onTriggered: cc.copied = "" }
    function copy(key, text) { Tailscale.copy(text); cc.copied = key; copiedReset.restart(); }

    component Section: T {
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.topMargin: 8
        Layout.bottomMargin: 2
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Theme.text2
    }
    component OptionRow: RowLayout {
        id: opt
        property string label: ""
        property bool checked: false
        signal toggled(bool v)
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 6
        Layout.preferredHeight: 30
        T { Layout.fillWidth: true; text: opt.label; font.pixelSize: 13 }
        Switch { checked: opt.checked; onToggled: v => { opt.toggled(v); checked = Qt.binding(() => opt.checked); } }
    }
}
