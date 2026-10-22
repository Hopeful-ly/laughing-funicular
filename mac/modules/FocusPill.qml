import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.widgets

// Deep Focus indicator: a small pill at the top centre. Hidden most of the
// time; appears for a moment at the start, when the pointer touches the top
// edge, when the session is complete, or when the app has closed.
PanelWindow {
    id: w
    readonly property string sname: screen ? screen.name : ""
    readonly property bool primary: Focus.active && (Focus.state.monitor === sname || Focus.state.monitor === "")
    visible: Focus.active
    anchors { top: true; left: true; right: true }
    implicitHeight: 44
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "mac-focus"
    WlrLayershell.layer: WlrLayer.Overlay

    property bool peek: false
    readonly property bool shown: primary && (peek || hover.hovered || Focus.complete || !Focus.appRunning || Focus.exitOpen)
    Timer { id: peekTimer; interval: 5000; onTriggered: w.peek = false }
    Connections { target: Focus; function onActiveChanged() { if (Focus.active) { w.peek = true; peekTimer.restart(); } } }
    Component.onCompleted: if (Focus.active) { peek = true; peekTimer.restart(); }

    mask: Region { item: w.shown ? pill : edge }
    Item { id: edge; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; width: 420; height: 2 }
    HoverHandler { id: hover; parent: w.contentItem }

    Glass {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: w.shown ? 6 : -height - 8
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        width: row.implicitWidth + 26
        height: 32
        radius: 16
        tint: Theme.glassThick
        absorb: false
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8; height: 8; radius: 4
                color: Focus.complete ? Theme.systemGreen : !Focus.appRunning ? Theme.systemOrange : "#ff375f"
                SequentialAnimation on opacity {
                    running: Focus.active && !Focus.complete; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
            IconImage { anchors.verticalCenter: parent.verticalCenter; implicitSize: 16; source: Apps.iconForAppId(Focus.appId) }
            T {
                anchors.verticalCenter: parent.verticalCenter
                text: Focus.complete ? "Session complete" : !Focus.appRunning ? Focus.appName + " closed" : "Deep Focus · " + Focus.appName
                font.pixelSize: 12; font.weight: Font.DemiBold
            }
            T {
                anchors.verticalCenter: parent.verticalCenter
                text: Focus.timed ? (Focus.complete ? "+" + Focus.fmt(Focus.elapsedSec - Focus.minutes * 60) : Focus.fmt(Focus.remainingSec) + " left") : Focus.fmt(Focus.elapsedSec)
                font.pixelSize: 12; font.features: { "tnum": 1 }
                color: Theme.text2
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 14; color: Theme.separator }
            T {
                anchors.verticalCenter: parent.verticalCenter
                text: !Focus.appRunning ? "Relaunch" : Focus.complete ? "Leave" : "Super Esc to leave"
                font.pixelSize: 11
                color: !Focus.appRunning || Focus.complete ? Theme.accent : Theme.text3
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!Focus.appRunning) Focus.relaunch(); else Focus.requestExit()
        }
    }
}
