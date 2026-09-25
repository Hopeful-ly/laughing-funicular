import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs.services
import qs.widgets

// One notification, macOS style. Used by toasts and Notification Center.
Glass {
    id: card
    required property var notif
    property bool toast: false
    property bool selected: false
    property bool expanded: false
    signal closed()
    signal activated()

    readonly property bool hasImage: notif && notif.image !== "" && notif.image !== undefined
    readonly property var acts: notif ? notif.actions.filter(a => a.identifier !== "default") : []
    readonly property var defaultAct: notif ? notif.actions.find(a => a.identifier === "default") : null

    radius: 18
    tint: toast ? Theme.glassThick : Theme.tile
    shadow: toast
    sheen: toast
    implicitHeight: col.implicitHeight + 24

    function ago(t) {
        const s = (Notifs.now - t) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m ago";
        if (s < 86400) return Math.floor(s / 3600) + "h ago";
        return Math.floor(s / 86400) + "d ago";
    }
    readonly property real created: notif ? (Notifs.times[notif.id] || Notifs.now) : 0

    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: "transparent"
        border.width: card.selected ? 2 : 0
        border.color: Theme.accent
    }

    HoverHandler { id: hov }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => {
            if (m.button === Qt.MiddleButton || m.button === Qt.RightButton) { card.closed(); return; }
            if (card.defaultAct) card.defaultAct.invoke();
            else if (card.notif.desktopEntry) { const e = Apps.byId(card.notif.desktopEntry); if (e) Windows.activateApp(e.startupClass || e.id) || Apps.launch(e); }
            card.activated();
        }
    }

    ColumnLayout {
        id: col
        x: 12; y: 12
        width: card.width - 24
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            IconImage {
                Layout.alignment: Qt.AlignTop
                implicitSize: 36
                source: card.notif ? Notifs.appIconFor(card.notif) : ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                RowLayout {
                    Layout.fillWidth: true
                    T { Layout.fillWidth: true; text: card.notif ? card.notif.summary : ""; font.pixelSize: 13; font.weight: Font.DemiBold }
                    T { text: card.ago(card.created); font.pixelSize: 11; color: Theme.text3 }
                }
                T {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notif ? card.notif.body.replace(/<[^>]*>/g, "") : ""
                    font.pixelSize: 12
                    color: Theme.text2
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 12 : 3
                    textFormat: Text.PlainText
                }
            }
            ClippingRectangle {
                visible: card.hasImage && card.notif.image !== card.notif.appIcon
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                radius: 8
                color: "transparent"
                Image { anchors.fill: parent; source: card.hasImage ? card.notif.image : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(96, 96) }
            }
        }

        // Inline reply
        Rectangle {
            visible: card.notif && card.notif.hasInlineReply
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: Theme.field
            TextInput {
                id: reply
                anchors.fill: parent
                anchors.leftMargin: 10; anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Config.fontFamily
                font.pixelSize: 12
                onAccepted: { card.notif.sendInlineReply(text); text = ""; }
                T { visible: parent.text === ""; anchors.verticalCenter: parent.verticalCenter; text: card.notif ? (card.notif.inlineReplyPlaceholder || "Reply…") : ""; color: Theme.text3; font.pixelSize: 12 }
            }
        }

        // Actions
        RowLayout {
            visible: card.acts.length > 0
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: card.acts.slice(0, 3)
                Hoverable {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    color: hovered ? Theme.tileHover : Theme.tile
                    T { anchors.centerIn: parent; text: modelData.text; font.pixelSize: 12; font.weight: Font.Medium }
                    onClicked: { modelData.invoke(); card.activated(); }
                }
            }
        }
    }

    // Close button (top-left, appears on hover, like macOS)
    Rectangle {
        visible: hov.hovered || card.selected
        x: -6; y: -6
        width: 20; height: 20; radius: 10
        color: Theme.glassThick
        border.width: 1
        border.color: Theme.separator
        Sym { anchors.centerIn: parent; name: "close"; size: 13; weight: 600; color: Theme.text2 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.closed() }
    }
}
