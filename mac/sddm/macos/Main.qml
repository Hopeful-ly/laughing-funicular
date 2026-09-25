// macOS-style SDDM login screen (Qt6 greeter, Theme-API 2.0).
// Layout follows the macOS lock/login screen: wallpaper, date + large clock,
// status top-right, small avatar + name + "Enter Password" at the bottom.
//
// Keys: type to enter the password · ↵ log in · Esc clear
//       Ctrl+S / F2 cycle session · ←/→ switch user (if several)
//       Ctrl+Alt+Del power menu
import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    FontLoader { id: inter; source: "assets/InterVariable.ttf" }
    FontLoader { id: symbols; source: "assets/MaterialSymbolsRounded.ttf" }
    readonly property string ui: inter.status === FontLoader.Ready ? inter.name : "sans-serif"
    readonly property string sym: symbols.name
    readonly property color accent: config.accent || "#5b7cff"

    // ---- State -----------------------------------------------------------
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string userName: ""
    property string realName: ""
    property string userIcon: ""
    property string sessionName: ""
    property bool busy: false
    property bool failed: false
    property bool powerOpen: false
    property bool sessionsOpen: false

    function login() {
        if (busy || userName === "") return;
        busy = true; failed = false;
        sddm.login(userName, pw.text, sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.busy = false; root.failed = true; pw.text = ""; shake.restart(); pw.forceActiveFocus(); }
        function onLoginSucceeded() { root.busy = false; }
    }

    // Hidden views that expose model data for the current indices.
    Repeater {
        model: userModel
        Item {
            required property int index
            required property string name
            required property string realName
            required property string icon
            Component.onCompleted: sync()
            Connections { target: root; function onUserIndexChanged() { parent && sync(); } }
            function sync() { if (index === root.userIndex) { root.userName = name; root.realName = realName || name; root.userIcon = icon; } }
        }
    }
    Repeater {
        model: sessionModel
        Item {
            required property int index
            required property string name
            Component.onCompleted: sync()
            Connections { target: root; function onSessionIndexChanged() { sync(); } }
            function sync() { if (index === root.sessionIndex) root.sessionName = name; }
        }
    }

    // ---- Background --------------------------------------------------------
    Image {
        id: bg
        anchors.fill: parent
        source: config.background || "assets/background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
    }
    // Faint vignettes keep the clock and name readable on bright pictures.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 0.3; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
        }
    }

    component Label: Text {
        font.family: root.ui
        color: "white"
        renderType: Text.QtRendering
    }
    component Glyph: Text {
        property string name: ""
        property bool filled: true
        text: name
        font.family: root.sym
        font.pixelSize: 16
        font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400 })
        color: "white"
        renderType: Text.QtRendering
    }

    // ---- Top right status: keyboard layout · session · power -------------
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.rightMargin: 16
        spacing: 14

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: keyboard.layouts.length > 1
            text: keyboard.layouts.length ? keyboard.layouts[keyboard.currentLayout].longName : ""
            font.pixelSize: 13; font.weight: Font.Medium
            MouseArea { anchors.fill: parent; onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length }
        }
        // Session (the only non-macOS item, kept subtle)
        Rectangle {
            id: sessionPill
            anchors.verticalCenter: parent.verticalCenter
            height: 24; radius: 12
            width: sessRow.implicitWidth + 18
            color: sessMa.containsMouse || root.sessionsOpen ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.12)
            Row {
                id: sessRow
                anchors.centerIn: parent
                spacing: 4
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "desktop_windows"; font.pixelSize: 14 }
                Label { anchors.verticalCenter: parent.verticalCenter; text: root.sessionName; font.pixelSize: 12; font.weight: Font.Medium }
                Glyph { anchors.verticalCenter: parent.verticalCenter; name: "expand_more"; font.pixelSize: 14 }
            }
            MouseArea { id: sessMa; anchors.fill: parent; hoverEnabled: true; onClicked: { root.sessionsOpen = !root.sessionsOpen; root.powerOpen = false; } }
        }
        Glyph {
            id: powerIcon
            anchors.verticalCenter: parent.verticalCenter
            name: "power_settings_new"; font.pixelSize: 18
            opacity: pwrMa.containsMouse || root.powerOpen ? 1 : 0.85
            MouseArea { id: pwrMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: { root.powerOpen = !root.powerOpen; root.sessionsOpen = false; } }
        }
    }

    // Drop-down menus (glass)
    component Menu: Rectangle {
        default property alias items: menuCol.data
        width: 210
        height: menuCol.implicitHeight + 12
        radius: 12
        color: Qt.rgba(0.12, 0.12, 0.14, 0.72)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Column { id: menuCol; x: 6; y: 6; width: parent.width - 12 }
    }
    component MenuRow: Rectangle {
        id: mr
        property string text: ""
        property string icon: ""
        property bool checked: false
        signal activated()
        width: parent ? parent.width : 200
        height: 30; radius: 7
        color: ma.containsMouse ? root.accent : "transparent"
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 8; spacing: 8
            Glyph { anchors.verticalCenter: parent.verticalCenter; name: mr.checked ? "check" : mr.icon; font.pixelSize: 16; filled: false }
            Label { anchors.verticalCenter: parent.verticalCenter; text: mr.text; font.pixelSize: 13 }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: mr.activated() }
    }

    Menu {
        visible: root.sessionsOpen
        anchors.top: parent.top; anchors.topMargin: 40
        anchors.right: parent.right; anchors.rightMargin: 16
        Repeater {
            model: sessionModel
            MenuRow {
                required property int index
                required property string name
                text: name
                icon: "desktop_windows"
                checked: index === root.sessionIndex
                onActivated: { root.sessionIndex = index; root.sessionsOpen = false; pw.forceActiveFocus(); }
            }
        }
    }
    Menu {
        visible: root.powerOpen
        anchors.top: parent.top; anchors.topMargin: 40
        anchors.right: parent.right; anchors.rightMargin: 16
        MenuRow { visible: sddm.canSuspend; text: "Sleep"; icon: "bedtime"; onActivated: sddm.suspend() }
        MenuRow { visible: sddm.canReboot; text: "Restart"; icon: "restart_alt"; onActivated: sddm.reboot() }
        MenuRow { visible: sddm.canPowerOff; text: "Shut Down"; icon: "power_settings_new"; onActivated: sddm.powerOff() }
    }

    // ---- Date + clock ---------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.085
        spacing: -root.height * 0.012
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "ddd d MMM")
            font.pixelSize: Math.round(root.height * 0.027)
            font.weight: Font.DemiBold
            opacity: 0.92
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, config.clock24h === "false" ? "h:mm" : "HH:mm")
            font.pixelSize: Math.round(root.height * 0.125)
            font.weight: Font.DemiBold
            font.letterSpacing: -2
            font.features: { "tnum": 1, "ss01": 1 }
            opacity: 0.88
        }
    }

    // ---- User + password (bottom centre) ---------------------------------------
    Column {
        id: userBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.07
        spacing: 8

        // Avatars: several users -> small row, current one highlighted.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            Repeater {
                model: userModel
                Item {
                    id: av
                    required property int index
                    required property string name
                    required property string realName
                    required property string icon
                    readonly property bool current: index === root.userIndex
                    // SDDM's generic placeholder face counts as "no picture".
                    readonly property bool hasFace: icon !== "" && icon.indexOf("/sddm/faces/.face.icon") < 0 && icon.indexOf("default") < 0
                    visible: current || userModel.count > 1
                    width: current ? 48 : 36; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: current ? 1 : 0.6
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Image {
                        id: face
                        anchors.fill: parent
                        source: av.hasFace ? av.icon : ""
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
                    MultiEffect {
                        anchors.fill: parent
                        source: face
                        maskEnabled: true
                        maskSource: faceMask
                        visible: av.hasFace && face.status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: !av.hasFace || face.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.lighter(root.accent, 1.35) }
                            GradientStop { position: 1; color: root.accent }
                        }
                        Label { anchors.centerIn: parent; text: (av.realName || av.name).charAt(0).toUpperCase(); font.pixelSize: parent.width * 0.45; font.weight: Font.DemiBold }
                    }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35) }
                    MouseArea { anchors.fill: parent; onClicked: { root.userIndex = av.index; pw.text = ""; pw.forceActiveFocus(); } }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.realName
            font.pixelSize: 14; font.weight: Font.DemiBold
        }

        // "Enter Password" text that becomes a capsule while typing.
        Item {
            id: fieldWrap
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200; height: 30
            Rectangle {
                id: capsule
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, active ? 0.20 : 0)
                border.width: active ? 1 : 0
                border.color: root.failed ? Qt.rgba(1, 0.5, 0.5, 0.7) : Qt.rgba(1, 1, 1, 0.28)
                readonly property bool active: pw.text.length > 0 || root.busy
                Behavior on color { ColorAnimation { duration: 160 } }

                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 14; anchors.rightMargin: 34
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignLeft
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    font.family: root.ui
                    font.pixelSize: 12
                    color: "white"
                    focus: true
                    enabled: !root.busy
                    onTextChanged: if (text.length) root.failed = false
                    onAccepted: root.login()
                    Keys.onEscapePressed: { text = ""; root.powerOpen = false; root.sessionsOpen = false; }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if ((ctrl && e.key === Qt.Key_S) || e.key === Qt.Key_F2) { root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount(); e.accepted = true; }
                        else if (text === "" && userModel.count > 1 && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
                            root.userIndex = (root.userIndex + (e.key === Qt.Key_Right ? 1 : userModel.count - 1)) % userModel.count; e.accepted = true;
                        }
                        else if (ctrl && (e.modifiers & Qt.AltModifier) && e.key === Qt.Key_Delete) { root.powerOpen = true; e.accepted = true; }
                    }
                }
                Label {
                    visible: !capsule.active
                    anchors.centerIn: parent
                    text: root.failed ? "Incorrect password" : "Enter Password"
                    font.pixelSize: 12; font.weight: Font.Medium
                    color: root.failed ? "#ffb4ae" : Qt.rgba(1, 1, 1, 0.78)
                }
                // Submit arrow / spinner
                Rectangle {
                    visible: capsule.active
                    anchors.right: parent.right; anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11
                    color: Qt.rgba(1, 1, 1, 0.28)
                    Glyph {
                        id: goGlyph
                        anchors.centerIn: parent
                        name: root.busy ? "progress_activity" : "arrow_forward"
                        font.pixelSize: 15
                        RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.login() }
                }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: capsule; property: "x"; to: -12; duration: 50 }
                NumberAnimation { target: capsule; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: capsule; property: "x"; to: -8; duration: 70 }
                NumberAnimation { target: capsule; property: "x"; to: 6; duration: 60 }
                NumberAnimation { target: capsule; property: "x"; to: 0; duration: 50 }
            }
        }

        // Small hints (fade in only when there's something to hint)
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "↵ log in   ·   Ctrl S session" + (userModel.count > 1 ? "   ·   ← → user" : "")
            font.pixelSize: 11
            color: Qt.rgba(1, 1, 1, 0.5)
            opacity: pw.text.length > 0 ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    // Click anywhere closes menus and keeps focus on the password.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: { root.powerOpen = false; root.sessionsOpen = false; pw.forceActiveFocus(); }
    }
    Component.onCompleted: pw.forceActiveFocus()
}
