import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.widgets

// Glass pull-down menu. Shell.menuItems is either an array of rows or
// { tray: QsMenuHandle } for StatusNotifier menus (with sub-menus).
//   rows: { text, icon, shortcut, checked, enabled, destructive, action }
//         { separator: true } | { header, right } | { info }
// Keys: ↑/↓ move · ↵ select · → open sub-menu · ←/Esc back/close
PopupLayer {
    id: menuLayer
    ns: "mac-menu"
    persistent: true
    panelItem: menu
    readonly property string sname: screen ? screen.name : ""
    open: Shell.menuOpen && Shell.menuScreen === sname
    openDuration: 120
    closeDuration: 110
    onDismissed: Shell.hideMenu()

    property var stack: []                 // tray sub-menu handles
    readonly property bool isTray: !Array.isArray(Shell.menuItems) && Shell.menuItems && Shell.menuItems.tray !== undefined
    readonly property var trayHandle: stack.length ? stack[stack.length - 1] : (isTray ? Shell.menuItems.tray : null)
    property int sel: -1

    onOpenChanged: if (open) { stack = []; sel = -1; keys.forceActiveFocus(); }

    QsMenuOpener { id: opener; menu: menuLayer.trayHandle }

    readonly property var rows: {
        if (!isTray) return Array.isArray(Shell.menuItems) ? Shell.menuItems : [];
        const out = [];
        if (stack.length) out.push({ text: "Back", icon: "chevron_left", back: true });
        for (const e of opener.children.values) {
            if (e.isSeparator) { out.push({ separator: true }); continue; }
            out.push({
                text: e.text.replace(/_(?=\w)/, ""), iconPath: e.icon, enabled: e.enabled,
                checked: e.buttonType !== QsMenuButtonType.None ? e.checkState === Qt.Checked : undefined,
                submenu: e.hasChildren ? e : null, entry: e
            });
        }
        return out;
    }
    function selectable(i) { const r = rows[i]; return r && !r.separator && r.header === undefined && r.info === undefined && r.enabled !== false; }
    function move(d) {
        let i = sel;
        for (let n = 0; n < rows.length; n++) {
            i = (i + d + rows.length) % rows.length;
            if (selectable(i)) { sel = i; return; }
        }
    }
    function activate(i) {
        const r = rows[i];
        if (!r || !selectable(i)) return;
        if (r.back) { stack = stack.slice(0, -1); sel = -1; return; }
        if (r.submenu) { stack = stack.concat([r.submenu]); sel = -1; return; }
        Shell.hideMenu();
        if (r.entry) r.entry.triggered();
        else if (r.action) Shell.later(r.action);   // after the menu releases the keyboard
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Down || (e.key === Qt.Key_N && e.modifiers & Qt.ControlModifier)) { menuLayer.move(1); e.accepted = true; }
            else if (e.key === Qt.Key_Up || (e.key === Qt.Key_P && e.modifiers & Qt.ControlModifier)) { menuLayer.move(-1); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { menuLayer.activate(menuLayer.sel); e.accepted = true; }
            else if (e.key === Qt.Key_Right && menuLayer.rows[menuLayer.sel] && menuLayer.rows[menuLayer.sel].submenu) { menuLayer.activate(menuLayer.sel); e.accepted = true; }
            else if (e.key === Qt.Key_Left && menuLayer.stack.length) { menuLayer.stack = menuLayer.stack.slice(0, -1); menuLayer.sel = -1; e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { Shell.hideMenu(); e.accepted = true; }
        }
    }

    Glass {
        id: menu
        radius: 12
        tint: Theme.glassThick
        width: Math.max(230, col.implicitWidth + 12)
        height: col.implicitHeight + 12
        x: Math.max(6, Math.min(menuLayer.width - width - 6, Shell.menuPos.x))
        y: Shell.menuAbove ? Math.max(4, Shell.menuPos.y - height) : Shell.menuPos.y
        opacity: menuLayer.t
        scale: 0.96 + 0.04 * menuLayer.t
        transformOrigin: Shell.menuAbove ? Item.Bottom : Item.TopLeft

        ColumnLayout {
            id: col
            x: 6; y: 6
            width: menu.width - 12
            spacing: 0
            Repeater {
                model: menuLayer.rows
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool isSep: !!modelData.separator
                    readonly property bool isHeader: modelData.header !== undefined
                    readonly property bool isInfo: modelData.info !== undefined
                    readonly property bool on: menuLayer.sel === index
                    readonly property bool dis: modelData.enabled === false
                    Layout.fillWidth: true
                    implicitHeight: isSep ? 11 : isHeader ? 26 : isInfo ? 22 : 26
                    implicitWidth: rowLay.implicitWidth + 20

                    Rectangle {
                        visible: row.isSep
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.separator
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: !row.isSep && !row.isHeader && !row.isInfo
                        radius: 7
                        color: row.on && !row.dis ? (row.modelData.destructive ? Theme.systemRed : Theme.accent) : "transparent"
                    }
                    RowLayout {
                        id: rowLay
                        visible: !row.isSep
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        spacing: 8
                        // checkmark column
                        Sym {
                            visible: row.modelData.checked !== undefined
                            Layout.preferredWidth: 14
                            name: row.modelData.checked ? "check" : ""
                            size: 15
                            weight: 600
                            color: row.on ? "white" : Theme.text
                        }
                        Sym {
                            visible: !!row.modelData.icon
                            Layout.preferredWidth: 18
                            name: row.modelData.icon || ""
                            size: 17
                            color: row.on && !row.dis ? "white" : row.dis ? Theme.text3 : row.modelData.destructive ? Theme.systemRed : Theme.text2
                        }
                        IconImage {
                            visible: !!row.modelData.iconPath
                            implicitSize: 16
                            source: row.modelData.iconPath || ""
                        }
                        T {
                            Layout.fillWidth: true
                            text: row.isHeader ? row.modelData.header : row.isInfo ? row.modelData.info : (row.modelData.text || "")
                            font.pixelSize: row.isInfo ? 12 : 13
                            font.weight: row.isHeader ? Font.Bold : Font.Normal
                            color: row.on && !row.dis ? "white" : row.dis ? Theme.text3 : row.isInfo ? Theme.text2 : Theme.text
                        }
                        T {
                            visible: !!row.modelData.right
                            text: row.modelData.right || ""
                            color: Theme.text2
                            font.pixelSize: 12
                        }
                        T {
                            visible: !!row.modelData.shortcut
                            text: row.modelData.shortcut || ""
                            color: row.on ? Qt.rgba(1, 1, 1, 0.8) : Theme.text3
                            font.pixelSize: 12
                        }
                        Sym {
                            visible: !!row.modelData.submenu
                            name: "chevron_right"
                            size: 16
                            color: row.on ? "white" : Theme.text2
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: menuLayer.selectable(row.index)
                        hoverEnabled: true
                        onEntered: menuLayer.sel = row.index
                        onExited: if (menuLayer.sel === row.index) menuLayer.sel = -1
                        onClicked: menuLayer.activate(row.index)
                    }
                }
            }
        }
    }
}
