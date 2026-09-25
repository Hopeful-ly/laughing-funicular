import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.UPower
import qs.services
import qs.widgets

// Lock screen visuals, shared by the real lock (WlSessionLock) and the preview.
Rectangle {
    id: root
    property bool preview: false
    color: "black"

    Image {
        id: wall
        anchors.fill: parent
        source: "file://" + Wallpaper.current
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 1920
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.08
        saturation: 0.1
    }

    SystemClock { id: clk; precision: SystemClock.Seconds }

    // Status (battery / input source) top right
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 14
        opacity: 0.9
        T { visible: Keyboard.count > 1; text: Keyboard.short; color: "white"; font.pixelSize: 13; font.weight: Font.Medium }
        T {
            visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
            text: Math.round((UPower.displayDevice ? UPower.displayDevice.percentage : 0) * 100) + "%"
            color: "white"; font.pixelSize: 13; font.weight: Font.Medium
        }
        Sym { name: Net.icon(); filled: true; size: 17; color: "white" }
    }

    // Date + time
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.09
        spacing: -6
        T {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(clk.date, "dddd d MMMM")
            color: Qt.rgba(1, 1, 1, 0.85)
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
        T {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(clk.date, Config.clock24h ? "HH:mm" : "h:mm")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.pixelSize: 120
            font.weight: Font.Bold
            font.features: { "tnum": 1 }
        }
    }

    // Media
    Glass {
        visible: Media.active
        width: 340; height: 72
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.42
        radius: 20
        tint: Qt.rgba(0.1, 0.1, 0.12, 0.35)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                T { Layout.fillWidth: true; text: Media.player ? Media.player.trackTitle : ""; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
                T { Layout.fillWidth: true; text: Media.player ? (Media.player.trackArtist || Media.player.identity) : ""; color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: 12 }
            }
            Repeater {
                model: [{ i: "skip_previous", f: () => Media.player.previous() }, { i: Media.player && Media.player.isPlaying ? "pause" : "play_arrow", f: () => Media.player.togglePlaying() }, { i: "skip_next", f: () => Media.player.next() }]
                Hoverable {
                    required property var modelData
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    hoverColor: Qt.rgba(1, 1, 1, 0.15)
                    Sym { anchors.centerIn: parent; name: modelData.i; filled: true; size: 22; color: "white" }
                    onClicked: modelData.f()
                }
            }
        }
    }

    // User + password
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.1
        spacing: 12

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64; height: 64; radius: 32
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(Theme.accent, 1.3) }
                GradientStop { position: 1; color: Theme.accent }
            }
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.35)
            T { anchors.centerIn: parent; text: Lock.realName.charAt(0).toUpperCase(); color: "white"; font.pixelSize: 28; font.weight: Font.DemiBold }
        }
        T {
            Layout.alignment: Qt.AlignHCenter
            text: Lock.realName
            color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold
        }

        Item {
            id: fieldWrap
            Layout.alignment: Qt.AlignHCenter
            width: 220; height: 34
            Rectangle {
                id: field
                anchors.fill: parent
                radius: 17
                color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1
                border.color: Lock.status === "failed" ? Qt.rgba(1, 0.4, 0.4, 0.7) : Qt.rgba(1, 1, 1, 0.25)
                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 36
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    font.family: Config.fontFamily
                    font.pixelSize: 13
                    focus: true
                    enabled: Lock.status !== "checking"
                    text: Lock.password
                    onTextChanged: { Lock.password = text; if (text !== "" && Lock.status === "failed") Lock.status = ""; }
                    onAccepted: root.preview ? Lock.previewing = false : Lock.submit()
                    Keys.onEscapePressed: { if (root.preview) Lock.previewing = false; else text = ""; }
                    T {
                        visible: pw.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: Lock.status === "checking" ? "Checking…" : "Enter Password"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 13
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    visible: pw.text !== "" || Lock.status === "checking"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    Sym { anchors.centerIn: parent; name: Lock.status === "checking" ? "progress_activity" : "arrow_forward"; size: 16; color: "white"
                          RotationAnimation on rotation { running: Lock.status === "checking"; from: 0; to: 360; duration: 900; loops: Animation.Infinite } }
                    MouseArea { anchors.fill: parent; onClicked: Lock.submit() }
                }
            }
            // Shake on failure
            SequentialAnimation {
                id: shake
                NumberAnimation { target: field; property: "x"; to: -12; duration: 50 }
                NumberAnimation { target: field; property: "x"; to: 12; duration: 70 }
                NumberAnimation { target: field; property: "x"; to: -8; duration: 70 }
                NumberAnimation { target: field; property: "x"; to: 6; duration: 60 }
                NumberAnimation { target: field; property: "x"; to: 0; duration: 50 }
            }
            Connections { target: Lock; function onFailuresChanged() { if (Lock.failures > 0) shake.restart(); } }
        }
        T {
            Layout.alignment: Qt.AlignHCenter
            text: root.preview ? "Preview · press ↵ or Esc to close" : Lock.status === "failed" ? "Incorrect password" : "Press ↵ to unlock"
            color: Lock.status === "failed" ? "#ff9f9a" : Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 12
        }
    }

    // Keep focus on the field wherever the user clicks.
    MouseArea { anchors.fill: parent; z: -1; onClicked: pw.forceActiveFocus() }
    Component.onCompleted: pw.forceActiveFocus()
}
