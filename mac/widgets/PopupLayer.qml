import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// Full-screen transparent overlay that hosts a floating panel. Clicking
// outside the panel calls dismissed(). `t` (0..1) drives open/close animation.
PanelWindow {
    id: pl
    property bool open: false
    property string ns: "mac-panel"
    property bool keyboard: true
    property int openDuration: 260
    property int closeDuration: 170
    // Keep the Wayland surface mapped while closed (invisible, click-through,
    // no keyboard focus) so opening is instant instead of creating a surface.
    property bool persistent: false
    // The visible panel. When set, only it takes input; clicks elsewhere go
    // through and (via the focus grab) close the popup. Unset = modal overlay.
    property Item panelItem: null
    readonly property string grabScreen: screen ? screen.name : ""
    signal dismissed()
    default property alias content: container.data

    property real t: open ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: pl.open ? pl.openDuration : pl.closeDuration
            easing.type: pl.open ? Easing.OutCubic : Easing.InCubic
        }
    }

    readonly property bool shown: open || t > 0.002
    visible: persistent || shown
    mask: !shown ? emptyRegion : panelItem ? panelRegion : null
    Region { id: emptyRegion }
    Region { id: panelRegion; item: pl.panelItem }

    HyprlandFocusGrab {
        active: pl.open && pl.panelItem !== null
        windows: [pl, Shell.bars[pl.grabScreen], Shell.docks[pl.grabScreen]].filter(w => !!w)
        onCleared: if (pl.open) pl.dismissed()
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive only for modal overlays; grabbed popups use OnDemand so the
    // bar still gets clicks (the focus grab hands the keyboard to the popup).
    WlrLayershell.keyboardFocus: !(open && keyboard) ? WlrKeyboardFocus.None : panelItem ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        enabled: pl.open
        acceptedButtons: Qt.AllButtons
        onPressed: pl.dismissed()
    }
    Item {
        id: container
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: pl.dismissed()
    }
}
