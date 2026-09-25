import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.widgets

// Real session lock (replaces hyprlock) + a non-locking preview overlay.
Scope {
    WlSessionLock {
        locked: Lock.locked
        WlSessionLockSurface {
            color: "black"
            LockContent { anchors.fill: parent }
        }
    }

    // `qs -c mac ipc call lock preview` — shows the design without locking.
    PanelWindow {
        visible: Lock.previewing
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "black"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "mac-lock-preview"
        WlrLayershell.keyboardFocus: Lock.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        LockContent { anchors.fill: parent; preview: true }
    }
}
