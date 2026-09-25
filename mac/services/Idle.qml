pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Idle behaviour (replaces hypridle, which isn't installed):
//   5 min lock · 10 min screen off · 30 min suspend.
// "Keep Awake" in Control Center disables all three; apps that inhibit idle
// (video players, browsers playing video) are respected too.
Singleton {
    id: root
    readonly property bool enabled: !Config.keepAwake

    IdleMonitor {
        enabled: root.enabled
        timeout: 300
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Lock.lock()
    }
    IdleMonitor {
        enabled: root.enabled
        timeout: 600
        respectInhibitors: true
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "disable" : "enable"}" })`)
    }
    IdleMonitor {
        enabled: root.enabled
        timeout: 1800
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) { Lock.lock(); Quickshell.execDetached(["systemctl", "suspend"]); }
    }
    function init() {}
}
