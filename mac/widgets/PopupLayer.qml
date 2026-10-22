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
    // A closed persistent popup shrinks to a single pixel: no full-screen
    // buffers to composite or blur, and its content stops rendering.
    anchors { top: true; left: true; bottom: pl.shown; right: pl.shown }
    implicitWidth: 1
    implicitHeight: 1
    mask: !shown ? emptyRegion : panelItem ? panelRegion : null
    Region { id: emptyRegion }
    Region { id: panelRegion; item: pl.panelItem }

    // Start the grab only once the surface has grown from its 1x1 idle size,
    // otherwise the compositor hands the keyboard to the bar instead.
    readonly property bool sized: width > 1 && height > 1
    // Only the popup itself is whitelisted: any surface in the list can end up
    // with the keyboard when the pointer crosses it (the dock did exactly that).
    // Clicking the bar or dock therefore closes the popup first; Shell.toggle
    // ignores a re-open of the same panel within a moment of that.
    HyprlandFocusGrab {
        active: pl.open && pl.panelItem !== null && pl.sized
        windows: [pl]
        onCleared: if (pl.open) { Shell.noteDismiss(); pl.dismissed(); }
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: ns
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive while open: Hyprland then keeps the keyboard on this surface
    // itself (with OnDemand it only did so once the pointer entered it). The
    // bar stays clickable because pointer input is not affected, and the
    // focus grab below handles click-outside-to-close.
    WlrLayershell.keyboardFocus: open && keyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        enabled: pl.open
        acceptedButtons: Qt.AllButtons
        onPressed: pl.dismissed()
    }
    Item {
        id: container
        anchors.fill: parent
        visible: pl.shown
        focus: true
        Keys.onEscapePressed: pl.dismissed()
    }
}
