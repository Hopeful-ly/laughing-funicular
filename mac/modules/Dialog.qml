import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Centred alert (Shut Down / Restart / Empty Trash …) with optional countdown.
// Keys: ↵ confirm · Esc cancel · Tab switch button
PopupLayer {
    id: dlg
    ns: "mac-dialog"
    readonly property string sname: screen ? screen.name : ""
    readonly property var d: Shell.dialog
    open: d !== null && sname === Shell.focusedScreen()
    onDismissed: Shell.dialog = null

    property int remaining: 0
    property int focusBtn: 1       // 0 cancel · 1 confirm
    onOpenChanged: if (open) { remaining = d.countdown || 0; focusBtn = 1; keys.forceActiveFocus(); }
    function confirm() { const a = d.action; Shell.dialog = null; if (a) a(); }

    Timer {
        interval: 1000; repeat: true
        running: dlg.open && dlg.remaining > 0
        onTriggered: { dlg.remaining--; if (dlg.remaining === 0) dlg.confirm(); }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.25 * dlg.t) }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { if (dlg.focusBtn === 1) dlg.confirm(); else Shell.dialog = null; }
            else if (e.key === Qt.Key_Escape) Shell.dialog = null;
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Left || e.key === Qt.Key_Right) dlg.focusBtn = 1 - dlg.focusBtn;
            else return;
            e.accepted = true;
        }
    }

    Glass {
        width: 280
        height: col.implicitHeight + 36
        anchors.centerIn: parent
        radius: 24
        tint: Theme.glassThick
        opacity: dlg.t
        scale: 0.9 + 0.1 * dlg.t
        ColumnLayout {
            id: col
            x: 18; y: 20
            width: parent.width - 36
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56; height: 56; radius: 14
                color: dlg.d && dlg.d.destructive ? Theme.systemRed : Theme.accent
                Sym { anchors.centerIn: parent; name: dlg.d ? dlg.d.icon || "help" : ""; size: 32; filled: true; color: "white" }
            }
            T {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: dlg.d ? dlg.d.title : ""
                font.pixelSize: 13; font.weight: Font.Bold
                wrapMode: Text.Wrap
            }
            T {
                Layout.fillWidth: true
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                text: dlg.d ? (dlg.d.body || (dlg.remaining > 0 ? "This will happen automatically in " + dlg.remaining + " seconds." : "")) : ""
                font.pixelSize: 12; color: Theme.text2
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                Repeater {
                    model: [{ label: "Cancel", idx: 0 }, { label: dlg.d ? dlg.d.confirm || "OK" : "OK", idx: 1 }]
                    Hoverable {
                        required property var modelData
                        readonly property bool primary: modelData.idx === dlg.focusBtn
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 15
                        color: primary ? (dlg.d && dlg.d.destructive && modelData.idx === 1 ? Theme.systemRed : Theme.accent) : hovered ? Theme.tileHover : Theme.tile
                        T { anchors.centerIn: parent; text: modelData.label; font.pixelSize: 13; font.weight: Font.Medium; color: parent.primary ? "white" : Theme.text }
                        onClicked: { if (modelData.idx === 1) dlg.confirm(); else Shell.dialog = null; }
                    }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                opacity: 0.8
                Hint { label: "Confirm"; keys: ["↵"] }
                Hint { label: "Cancel"; keys: ["Esc"] }
                Hint { label: "Switch"; keys: ["Tab"] }
            }
        }
    }
}
