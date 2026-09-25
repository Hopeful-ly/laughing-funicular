import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.services
import qs.widgets

// Banner notifications, top-right, on the focused screen.
PanelWindow {
    id: w
    readonly property string sname: screen ? screen.name : ""
    readonly property bool here: sname === Shell.focusedScreen()
    visible: here && Notifs.popups.length > 0 && !Shell.isOpen("notifications", sname)
    anchors { top: true; right: true }
    margins { top: Config.barHeight + 4; right: 8 }
    implicitWidth: 372
    implicitHeight: Math.min(stack.implicitHeight + 16, (screen ? screen.height : 900) - 100)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mac-toast"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: stack
        x: 8; y: 8
        width: w.width - 16
        spacing: 8
        move: Transition { NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic } }
        Repeater {
            model: Notifs.popups
            delegate: NotifCard {
                id: card
                required property var modelData
                notif: modelData
                toast: true
                width: stack.width
                opacity: 0
                x: 40
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                onClosed: Notifs.dismiss(modelData)
                onActivated: Notifs.dismiss(modelData)
                HoverHandler { id: hh }
                Timer {
                    interval: modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : (modelData.urgency === NotificationUrgency.Critical ? 0 : 5500)
                    running: interval > 0 && !hh.hovered
                    onTriggered: Notifs.removePopup(card.modelData)
                }
            }
        }
    }
}
