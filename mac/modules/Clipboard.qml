import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.widgets

// Clipboard history (Super+V), Raycast style: list + preview.
// ↵ paste · Ctrl+↵ copy · Ctrl+P pin · Ctrl+D delete · Ctrl+S save image · Ctrl+O open link
// Tab / ⇧Tab filter · Ctrl+K actions · Ctrl+⇧⌫ clear history · Esc close
PopupLayer {
    id: clp
    ns: "mac-launcher"
    persistent: true
    panelItem: win
    readonly property string sname: screen ? screen.name : ""
    open: Shell.isOpen("clipboard", sname)
    openDuration: 130
    closeDuration: 100
    onDismissed: Shell.close()

    property string query: ""
    property int sel: 0
    property int filter: 0
    readonly property var filters: [
        { name: "All", icon: "apps", kinds: null },
        { name: "Pinned", icon: "keep", kinds: "pinned" },
        { name: "Text", icon: "notes", kinds: ["text", "file"] },
        { name: "Images", icon: "image", kinds: ["image"] },
        { name: "Links", icon: "link", kinds: ["link"] },
        { name: "Colors", icon: "palette", kinds: ["color"] }
    ]
    property bool actionsOpen: false
    property int actSel: 0
    property string toast: ""
    property string previewText: ""
    property string previewImage: ""

    onOpenChanged: if (open) { Clip.refresh(); input.text = ""; sel = 0; filter = 0; actionsOpen = false; toast = ""; input.forceActiveFocus(); }
    onQueryChanged: sel = 0
    onFilterChanged: sel = 0

    readonly property var items: {
        if (!open) return [];
        const q = query.trim().toLowerCase();
        const f = filters[filter];
        const match = (e) => (!q || (e.kind === "image" ? ("image " + (e.meta.fmt || "")) : (e.text || e.preview)).toLowerCase().indexOf(q) >= 0)
                          && (!f.kinds || f.kinds === "pinned" || f.kinds.indexOf(e.kind) >= 0);
        const out = [];
        for (const p of Clip.pins) {
            const e = { pid: p.pid, src: p.src, kind: p.kind, text: p.text || "", file: p.file || "", preview: p.preview, meta: p.meta || {}, section: "Pinned" };
            if (match(e)) out.push(e);
        }
        if (f.kinds !== "pinned") {
            const pinnedSrc = Clip.pins.map(p => p.src);
            for (const e of Clip.entries) {
                if (pinnedSrc.indexOf(e.id) >= 0) continue;
                if (!match(e)) continue;
                out.push(Object.assign({ section: "Recent" }, e));
                if (out.length > 300) break;
            }
        }
        return out;
    }
    readonly property var current: items[sel] || null

    // ---- Preview loading ----------------------------------------------------
    onCurrentChanged: loadPreview()
    function loadPreview() {
        previewText = ""; previewImage = "";
        const e = current;
        if (!e) return;
        if (e.pid !== undefined) {
            if (e.kind === "image") previewImage = "file://" + e.file;
            else previewText = e.text;
            return;
        }
        if (e.kind === "image") Clip.decodeImage(e);
        else if (e.kind !== "binary") Clip.decodeText(e);
    }
    Connections {
        target: Clip
        function onDecoded(id, text) { if (clp.current && clp.current.id === id) clp.previewText = text; }
        function onImageReady(id, path) { if (clp.current && clp.current.id === id) clp.previewImage = "file://" + path; }
    }

    function flash(m) { toast = m; toastTimer.restart(); }
    Timer { id: toastTimer; interval: 1500; onTriggered: clp.toast = "" }

    readonly property var actions: {
        const e = current;
        if (!e) return [];
        const pinned = Clip.isPinned(e);
        const a = [
            { title: "Paste to Active Window", icon: "content_paste_go", keys: ["↵"], fn: () => { Shell.close(); Clip.paste(e); } },
            { title: "Copy to Clipboard", icon: "content_copy", keys: ["Ctrl", "↵"], hot: "ctrl+return", fn: () => { Clip.copy(e); Shell.close(); } },
            { title: pinned ? "Unpin" : "Pin", icon: "keep", keys: ["Ctrl", "P"], hot: "ctrl+p", fn: () => { Clip.togglePin(e); clp.flash(pinned ? "Unpinned" : "Pinned — kept even when history is cleared"); } }
        ];
        if (e.kind === "link") a.push({ title: "Open Link", icon: "open_in_new", keys: ["Ctrl", "O"], hot: "ctrl+o", fn: () => { Quickshell.execDetached(["xdg-open", (e.text || clp.previewText || e.preview).trim()]); Shell.close(); } });
        if (e.kind === "file") a.push({ title: "Open File", icon: "open_in_new", keys: ["Ctrl", "O"], hot: "ctrl+o", fn: () => { Quickshell.execDetached(["xdg-open", (e.text || clp.previewText || e.preview).trim().replace(/^file:\/\//, "").replace(/^~/, Quickshell.env("HOME"))]); Shell.close(); } });
        if (e.kind === "image") a.push({ title: "Save Image to Pictures", icon: "download", keys: ["Ctrl", "S"], hot: "ctrl+s", fn: () => { Clip.saveImage(e); clp.flash("Saved to ~/Pictures"); } });
        if (e.kind === "text" || e.kind === "link") a.push({ title: "Paste as Plain Single Line", icon: "short_text", keys: ["Ctrl", "⇧", "↵"], hot: "ctrl+shift+return", fn: () => { Quickshell.clipboardText = (clp.previewText || e.text || e.preview).replace(/\s+/g, " ").trim(); Shell.close(); Clip.sendPaste(); } });
        a.push({ title: pinned && e.pid !== undefined ? "Delete Pin" : "Delete Entry", icon: "delete", keys: ["Ctrl", "D"], hot: "ctrl+d", destructive: true, fn: () => { Clip.remove(e); clp.sel = Math.max(0, Math.min(clp.sel, clp.items.length - 2)); clp.flash("Deleted"); } });
        a.push({ title: "Clear History…", icon: "delete_sweep", keys: ["Ctrl", "⇧", "⌫"], hot: "ctrl+shift+backspace", destructive: true, fn: () => clp.askWipe() });
        return a;
    }
    function askWipe() {
        Shell.close();
        Shell.ask({ title: "Clear clipboard history?", body: "All " + Clip.entries.length + " items will be removed. Pinned items are kept.", icon: "delete_sweep", confirm: "Clear", destructive: true, action: () => Clip.wipe() });
    }
    function hotString(e) {
        let s = "";
        if (e.modifiers & Qt.ControlModifier) s += "ctrl+";
        if (e.modifiers & Qt.ShiftModifier) s += "shift+";
        const k = e.key === Qt.Key_Return || e.key === Qt.Key_Enter ? "return" : e.key === Qt.Key_Backspace ? "backspace" : String.fromCharCode(e.key).toLowerCase();
        return s + k;
    }
    function move(d) {
        if (actionsOpen) { actSel = Math.max(0, Math.min(actions.length - 1, actSel + d)); return; }
        sel = Math.max(0, Math.min(items.length - 1, sel + d));
        list.positionViewAtIndex(sel, ListView.Contain);
    }

    function kindIcon(k) { return ({ text: "notes", link: "link", color: "palette", file: "description", image: "image", binary: "draft" })[k] || "notes"; }
    function kindName(k) { return ({ text: "Text", link: "Link", color: "Color", file: "File path", image: "Image", binary: "Binary" })[k] || "Text"; }

    Glass {
        id: win
        width: 820
        height: 500
        radius: 16
        tint: Theme.glassThick
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.16)
        opacity: clp.t
        scale: 0.98 + 0.02 * clp.t

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---- Search + filter ------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                Layout.leftMargin: 16
                Layout.rightMargin: 12
                spacing: 10
                Sym { name: "content_paste_search"; size: 22; color: Theme.text2 }
                TextInput {
                    id: input
                    Layout.fillWidth: true
                    font.family: Config.fontFamily
                    font.pixelSize: 18
                    color: Theme.text
                    selectionColor: Theme.selection
                    clip: true
                    focus: true
                    onTextChanged: clp.query = text
                    T { visible: input.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search clipboard history…"; font.pixelSize: 18; color: Theme.text3 }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) { if (clp.actionsOpen) clp.actionsOpen = false; else if (input.text) input.text = ""; else Shell.close(); e.accepted = true; return; }
                        if (e.key === Qt.Key_K && ctrl) { clp.actionsOpen = !clp.actionsOpen; clp.actSel = 0; e.accepted = true; return; }
                        if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_N)) { clp.move(1); e.accepted = true; return; }
                        if (e.key === Qt.Key_Up) { clp.move(-1); e.accepted = true; return; }
                        if (e.key === Qt.Key_PageDown) { clp.move(8); e.accepted = true; return; }
                        if (e.key === Qt.Key_PageUp) { clp.move(-8); e.accepted = true; return; }
                        if (e.key === Qt.Key_Tab) { clp.filter = (clp.filter + 1) % clp.filters.length; e.accepted = true; return; }
                        if (e.key === Qt.Key_Backtab) { clp.filter = (clp.filter + clp.filters.length - 1) % clp.filters.length; e.accepted = true; return; }
                        if ((e.modifiers & Qt.AltModifier) && e.key >= Qt.Key_1 && e.key <= Qt.Key_9) { const i = e.key - Qt.Key_1; if (clp.items[i]) { clp.sel = i; clp.actions[0].fn(); } e.accepted = true; return; }
                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !ctrl && !(e.modifiers & Qt.ShiftModifier)) {
                            if (clp.actionsOpen) { const a = clp.actions[clp.actSel]; clp.actionsOpen = false; if (a) a.fn(); }
                            else if (clp.actions.length) clp.actions[0].fn();
                            e.accepted = true; return;
                        }
                        if (ctrl) {
                            const h = clp.hotString(e);
                            if (h === "ctrl+shift+backspace") { clp.askWipe(); e.accepted = true; return; }
                            const a = clp.actions.find(x => x.hot === h);
                            if (a) { clp.actionsOpen = false; a.fn(); e.accepted = true; }
                        }
                    }
                }
                // Filter pill (click or Tab)
                Hoverable {
                    implicitHeight: 28
                    implicitWidth: fRow.implicitWidth + 18
                    radius: 8
                    color: hovered ? Theme.tileHover : Theme.field
                    Row {
                        id: fRow
                        anchors.centerIn: parent
                        spacing: 6
                        Sym { anchors.verticalCenter: parent.verticalCenter; name: clp.filters[clp.filter].icon; size: 15; color: Theme.text2 }
                        T { anchors.verticalCenter: parent.verticalCenter; text: clp.filters[clp.filter].name; font.pixelSize: 12; font.weight: Font.Medium }
                        Kbd { anchors.verticalCenter: parent.verticalCenter; keys: ["Tab"] }
                    }
                    onClicked: { clp.filter = (clp.filter + 1) % clp.filters.length; input.forceActiveFocus(); }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ---- List ------------------------------------------------------
                ListView {
                    id: list
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    clip: true
                    model: clp.items
                    boundsBehavior: Flickable.StopAtBounds
                    reuseItems: true
                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool header: index === 0 || clp.items[index - 1].section !== modelData.section
                        readonly property bool isSel: index === clp.sel
                        width: list.width
                        height: (header ? 28 : 0) + 38
                        T {
                            visible: row.header
                            x: 20; y: 9
                            text: row.modelData.section + (row.modelData.section === "Recent" ? "  ·  " + Clip.entries.length : "")
                            font.pixelSize: 11; font.weight: Font.DemiBold
                            color: Theme.text3
                        }
                        Rectangle {
                            x: 8
                            y: row.header ? 28 : 0
                            width: parent.width - 16
                            height: 38
                            radius: 9
                            color: row.isSel ? Theme.selection : rm.containsMouse ? Theme.hover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Item {
                                    Layout.preferredWidth: 20; Layout.preferredHeight: 20
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: row.modelData.kind === "color"
                                        radius: 5
                                        color: row.modelData.kind === "color" ? (row.modelData.text || row.modelData.preview).trim() : "transparent"
                                        border.width: 1; border.color: Theme.separator
                                    }
                                    Sym {
                                        anchors.centerIn: parent
                                        visible: row.modelData.kind !== "color"
                                        name: clp.kindIcon(row.modelData.kind)
                                        size: 17
                                        color: row.isSel ? "white" : Theme.text2
                                    }
                                }
                                T {
                                    Layout.fillWidth: true
                                    text: row.modelData.kind === "image" ? "Image (" + (row.modelData.meta.w || "?") + "×" + (row.modelData.meta.h || "?") + ")"
                                                                         : (row.modelData.text || row.modelData.preview).replace(/\s+/g, " ").trim()
                                    font.pixelSize: 13
                                    color: row.isSel ? "white" : Theme.text
                                }
                                Sym {
                                    visible: row.modelData.pid !== undefined
                                    name: "keep"; size: 14; filled: true
                                    color: row.isSel ? "white" : Theme.systemOrange
                                }
                                T {
                                    visible: row.index < 9 && !row.header || row.index < 9
                                    text: row.index < 9 ? "Alt " + (row.index + 1) : ""
                                    font.pixelSize: 10
                                    color: row.isSel ? Qt.rgba(1, 1, 1, 0.7) : Theme.text3
                                    opacity: row.isSel || rm.containsMouse ? 1 : 0
                                }
                            }
                            MouseArea {
                                id: rm
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: m => {
                                    clp.sel = row.index;
                                    if (m.button === Qt.RightButton) { clp.actionsOpen = true; clp.actSel = 0; }
                                    input.forceActiveFocus();
                                }
                                onDoubleClicked: { clp.sel = row.index; if (clp.actions.length) clp.actions[0].fn(); }
                            }
                        }
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: clp.items.length === 0
                        spacing: 6
                        Sym { Layout.alignment: Qt.AlignHCenter; name: clp.filter === 1 ? "keep" : "content_paste_off"; size: 34; color: Theme.text3 }
                        T { Layout.alignment: Qt.AlignHCenter; text: Clip.loading ? "Loading…" : clp.filter === 1 ? "No pinned items — Ctrl+P pins" : "Nothing here yet"; font.pixelSize: 13; color: Theme.text2 }
                    }
                }

                Rectangle { Layout.fillHeight: true; width: 1; color: Theme.separator }

                // ---- Preview -------------------------------------------------------
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 14
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Image
                        Image {
                            anchors.fill: parent
                            visible: clp.current && clp.current.kind === "image"
                            source: visible ? clp.previewImage : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            sourceSize.width: 900
                        }
                        // Colour swatch
                        Rectangle {
                            visible: clp.current && clp.current.kind === "color"
                            anchors.centerIn: parent
                            width: Math.min(parent.width, 200); height: width * 0.6
                            radius: 14
                            color: visible ? (clp.current.text || clp.current.preview).trim() : "transparent"
                            border.width: 1; border.color: Theme.separator
                        }
                        // Text
                        Flickable {
                            id: flick
                            anchors.fill: parent
                            visible: clp.current && clp.current.kind !== "image" && clp.current.kind !== "color"
                            contentHeight: pre.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true
                            TextEdit {
                                id: pre
                                width: flick.width
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                text: clp.previewText.length > 20000 ? clp.previewText.slice(0, 20000) + "\n…" : (clp.previewText || (clp.current ? clp.current.preview : ""))
                                font.family: clp.current && clp.current.kind === "text" && /[{};<>=]/.test(clp.previewText) ? Config.monoFont : Config.fontFamily
                                font.pixelSize: 13
                                color: Theme.text
                                selectionColor: Theme.selection
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }

                    // Metadata
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 4
                        columnSpacing: 10
                        visible: clp.current !== null
                        readonly property string body: clp.previewText
                        T { text: "Type"; font.pixelSize: 12; color: Theme.text2 }
                        T { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: clp.current ? clp.kindName(clp.current.kind) + (clp.current.pid !== undefined ? " · Pinned" : "") : ""; font.pixelSize: 12 }
                        T { visible: clp.current && clp.current.kind === "image"; text: "Dimensions"; font.pixelSize: 12; color: Theme.text2 }
                        T { visible: clp.current && clp.current.kind === "image"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: clp.current && clp.current.meta ? (clp.current.meta.w + " × " + clp.current.meta.h + "  ·  " + (clp.current.meta.size || "") + " " + (clp.current.meta.fmt || "").toUpperCase()) : ""; font.pixelSize: 12 }
                        T { visible: clp.current && clp.current.kind !== "image"; text: "Characters"; font.pixelSize: 12; color: Theme.text2 }
                        T { visible: clp.current && clp.current.kind !== "image"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: parent.body.length.toLocaleString(); font.pixelSize: 12 }
                        T { visible: clp.current && clp.current.kind !== "image"; text: "Words · Lines"; font.pixelSize: 12; color: Theme.text2 }
                        T { visible: clp.current && clp.current.kind !== "image"; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: (parent.body.trim() ? parent.body.trim().split(/\s+/).length : 0) + " · " + (parent.body ? parent.body.split("\n").length : 0); font.pixelSize: 12 }
                    }
                }
            }

            // ---- Footer -------------------------------------------------------
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.separator }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.leftMargin: 14
                Layout.rightMargin: 10
                spacing: 10
                Sym { name: clp.toast ? "check_circle" : "content_paste"; size: 16; filled: true; color: clp.toast ? Theme.systemGreen : Theme.systemOrange }
                T { Layout.fillWidth: true; text: clp.toast || "Clipboard History"; font.pixelSize: 12; color: Theme.text2 }
                Hint { label: "Pin"; keys: ["Ctrl", "P"] }
                Hint { label: "Delete"; keys: ["Ctrl", "D"] }
                Rectangle { width: 1; height: 16; color: Theme.separator }
                Hint { label: "Paste"; keys: ["↵"]; strong: true }
                Rectangle { width: 1; height: 16; color: Theme.separator }
                Hint { label: "Actions"; keys: ["Ctrl", "K"] }
            }
        }

        // ---- Action panel ------------------------------------------------------
        Glass {
            visible: clp.actionsOpen && clp.actions.length > 0
            radius: 12
            tint: Theme.glassThick
            width: 310
            height: acol.implicitHeight + 12
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 10
            anchors.bottomMargin: 48
            ColumnLayout {
                id: acol
                x: 6; y: 6
                width: parent.width - 12
                spacing: 0
                Repeater {
                    model: clp.actionsOpen ? clp.actions : []
                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 7
                        color: index === clp.actSel ? (modelData.destructive ? Theme.systemRed : Theme.accent) : am.containsMouse ? Theme.hover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Sym { name: modelData.icon; size: 16; color: index === clp.actSel ? "white" : modelData.destructive ? Theme.systemRed : Theme.text2 }
                            T { Layout.fillWidth: true; text: modelData.title; font.pixelSize: 13; color: index === clp.actSel ? "white" : Theme.text }
                            Kbd { keys: modelData.keys || []; textColor: index === clp.actSel ? "white" : Theme.text2 }
                        }
                        MouseArea { id: am; anchors.fill: parent; hoverEnabled: true; onEntered: clp.actSel = index; onClicked: { clp.actionsOpen = false; modelData.fn(); input.forceActiveFocus(); } }
                    }
                }
            }
        }
    }
}
