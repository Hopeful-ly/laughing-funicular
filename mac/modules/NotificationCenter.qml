import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.widgets

// Notification Center (click the clock / Super+N): calendar widget + grouped history.
// Keys: ↑/↓ select · ↵ open · Del dismiss · ⇧Del clear app · Ctrl+⌫ clear all · D Do Not Disturb · ←/→ month
PopupLayer {
    id: nc
    ns: "mac-panel"
    persistent: true
    panelItem: panel
    readonly property string sname: screen ? screen.name : ""
    open: Shell.isOpen("notifications", sname)
    onDismissed: Shell.close()

    property int sel: -1
    property var month: new Date()
    readonly property var flat: {
        const out = [];
        for (const g of Notifs.groups) for (const n of g.items) out.push(n);
        return out;
    }
    onOpenChanged: if (open) { sel = -1; month = new Date(); keys.forceActiveFocus(); }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            const n = nc.flat[nc.sel];
            if (e.key === Qt.Key_Down || e.key === Qt.Key_J) nc.sel = Math.min(nc.flat.length - 1, nc.sel + 1);
            else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) nc.sel = Math.max(0, nc.sel - 1);
            else if ((e.key === Qt.Key_Backspace && ctrl)) Notifs.clearAll();
            else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && n) {
                if (e.modifiers & Qt.ShiftModifier) Notifs.clearApp(n.appName); else n.dismiss();
                nc.sel = Math.min(nc.sel, nc.flat.length - 2);
            }
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && n) {
                const d = n.actions.find(a => a.identifier === "default");
                if (d) d.invoke();
                Shell.close();
            }
            else if (e.key === Qt.Key_D) Config.dnd = !Config.dnd;
            else if (e.key === Qt.Key_Left) nc.month = new Date(nc.month.getFullYear(), nc.month.getMonth() - 1, 1);
            else if (e.key === Qt.Key_Right) nc.month = new Date(nc.month.getFullYear(), nc.month.getMonth() + 1, 1);
            else if (e.key === Qt.Key_T) nc.month = new Date();
            else if (e.key === Qt.Key_Escape) Shell.close();
            else return;
            e.accepted = true;
        }
    }

    Glass {
        id: panel
        width: 380
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 6
        radius: 26
        readonly property real maxH: nc.height - 12
        height: Math.min(maxH, col.implicitHeight + 24)
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        opacity: nc.t
        transform: Translate { x: (1 - nc.t) * 40 }
        clip: true

        ColumnLayout {
            id: col
            x: 12; y: 12
            width: panel.width - 24
            height: panel.height - 24
            spacing: 10

            // ---- Calendar widget -----------------------------------------
            CCTile {
                Layout.fillWidth: true
                Layout.preferredHeight: cal.implicitHeight + 28
                radius: 20
                SystemClock { id: clk; precision: SystemClock.Minutes }
                ColumnLayout {
                    id: cal
                    x: 16; y: 14
                    width: parent.width - 32
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            T { text: Qt.formatDate(clk.date, "dddd").toUpperCase(); font.pixelSize: 11; font.weight: Font.Bold; color: Theme.systemRed }
                            T { text: Qt.formatDate(nc.month, "MMMM yyyy"); font.pixelSize: 16; font.weight: Font.Bold }
                        }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [{ i: "chevron_left", d: -1 }, { i: "today", d: 0 }, { i: "chevron_right", d: 1 }]
                            Hoverable {
                                required property var modelData
                                implicitWidth: 26; implicitHeight: 26; radius: 13
                                Sym { anchors.centerIn: parent; name: modelData.i; size: 17; color: Theme.text2 }
                                onClicked: nc.month = modelData.d === 0 ? new Date() : new Date(nc.month.getFullYear(), nc.month.getMonth() + modelData.d, 1)
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 0
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            T { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.text3 }
                        }
                        Repeater {
                            model: {
                                const y = nc.month.getFullYear(), m = nc.month.getMonth();
                                const first = (new Date(y, m, 1).getDay() + 6) % 7;
                                const out = [];
                                for (let i = 0; i < 42; i++) {
                                    const d = new Date(y, m, i - first + 1);
                                    out.push({ day: d.getDate(), inMonth: d.getMonth() === m, today: d.toDateString() === clk.date.toDateString() });
                                }
                                // drop trailing week if entirely next month
                                return out[35].inMonth ? out : out.slice(0, 35);
                            }
                            Item {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 26
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 24; height: 24; radius: 12
                                    color: modelData.today ? Theme.systemRed : "transparent"
                                }
                                T {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: 12
                                    font.weight: modelData.today ? Font.Bold : Font.Normal
                                    color: modelData.today ? "white" : modelData.inMonth ? Theme.text : Theme.text3
                                }
                            }
                        }
                    }
                }
            }

            // ---- Header -------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 4
                T { text: "Notifications"; font.pixelSize: 15; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Hoverable {
                    implicitWidth: dndRow.implicitWidth + 16; implicitHeight: 26; radius: 13
                    color: Config.dnd ? Theme.accent : hovered ? Theme.tileHover : Theme.tile
                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 4
                        Sym { anchors.verticalCenter: parent.verticalCenter; name: "dark_mode"; filled: true; size: 14; color: Config.dnd ? Theme.accentText : Theme.text }
                        T { anchors.verticalCenter: parent.verticalCenter; text: "Do Not Disturb"; font.pixelSize: 11; color: Config.dnd ? Theme.accentText : Theme.text }
                    }
                    onClicked: Config.dnd = !Config.dnd
                }
                Hoverable {
                    visible: Notifs.count > 0
                    implicitWidth: clr.implicitWidth + 16; implicitHeight: 26; radius: 13
                    color: hovered ? Theme.tileHover : Theme.tile
                    T { id: clr; anchors.centerIn: parent; text: "Clear All"; font.pixelSize: 11 }
                    onClicked: Notifs.clearAll()
                }
            }

            // ---- List ------------------------------------------------------
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Notifs.count === 0 ? 110 : contentHeight
                Layout.fillHeight: true
                Layout.minimumHeight: Math.min(contentHeight, 110)
                clip: true
                spacing: 8
                model: Notifs.groups
                boundsBehavior: Flickable.StopAtBounds
                delegate: ColumnLayout {
                    id: grp
                    required property var modelData
                    required property int index
                    property bool expanded: modelData.items.length <= 1
                    width: list.width
                    spacing: 6
                    RowLayout {
                        visible: grp.modelData.items.length > 1
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        T { Layout.fillWidth: true; text: grp.modelData.app; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.text2 }
                        Hoverable {
                            implicitWidth: showT.implicitWidth + 14; implicitHeight: 22; radius: 11
                            color: hovered ? Theme.tileHover : Theme.tile
                            T { id: showT; anchors.centerIn: parent; text: grp.expanded ? "Show Less" : grp.modelData.items.length + " more"; font.pixelSize: 11 }
                            onClicked: grp.expanded = !grp.expanded
                        }
                        Hoverable {
                            implicitWidth: 22; implicitHeight: 22; radius: 11
                            color: hovered ? Theme.tileHover : Theme.tile
                            Sym { anchors.centerIn: parent; name: "close"; size: 13 }
                            onClicked: Notifs.clearApp(grp.modelData.app)
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: stackCol.implicitHeight + (grp.expanded ? 0 : Math.min(2, grp.modelData.items.length - 1) * 8)
                        Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        // Collapsed stack "shadow" cards
                        Repeater {
                            model: grp.expanded ? 0 : Math.min(2, grp.modelData.items.length - 1)
                            Rectangle {
                                required property int index
                                color: Theme.tile
                                z: -index - 1
                                width: parent.width - (index + 1) * 16
                                x: (index + 1) * 8
                                y: stackCol.implicitHeight - 40 + (index + 1) * 8
                                height: 40
                                radius: 16
                                opacity: 0.8 - index * 0.2
                            }
                        }
                        Column {
                            id: stackCol
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: grp.expanded ? grp.modelData.items : grp.modelData.items.slice(0, 1)
                                NotifCard {
                                    required property var modelData
                                    notif: modelData
                                    width: stackCol.width
                                    selected: nc.flat.indexOf(modelData) === nc.sel
                                    expanded: selected
                                    onClosed: modelData.dismiss()
                                    onActivated: Shell.close()
                                }
                            }
                        }
                    }
                }

                // Empty state
                ColumnLayout {
                    visible: Notifs.count === 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    spacing: 6
                    Sym { Layout.alignment: Qt.AlignHCenter; name: "notifications_off"; size: 34; color: Theme.text3 }
                    T { Layout.alignment: Qt.AlignHCenter; text: "No Notifications"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.text2 }
                }
            }

            // ---- Hints -----------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Hint { label: "Dismiss"; keys: ["Del"] }
                    Hint { label: "Clear"; keys: ["Ctrl", "⌫"] }
                    Hint { label: "Focus"; keys: ["D"] }
                }
            }
        }
    }
}
