//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
// macOS-style desktop shell for Hyprland.
// Layers: wallpaper, menu bar, dock, Control Center, Notification Center,
// toasts, OSD, launcher (Raycast-style) and clipboard history.
import QtQuick
import Quickshell
import qs.services
import qs.modules

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                id: perScreen
                required property var modelData
                WallpaperLayer { screen: perScreen.modelData }
                MenuBar { screen: perScreen.modelData }
                Dock { screen: perScreen.modelData }
                ControlCenter { screen: perScreen.modelData }
                SystemPanel { screen: perScreen.modelData }
                NotificationCenter { screen: perScreen.modelData }
                Toasts { screen: perScreen.modelData }
                Osd { screen: perScreen.modelData }
                Launcher { screen: perScreen.modelData }
                Clipboard { screen: perScreen.modelData }
                ContextMenu { screen: perScreen.modelData }
                Dialog { screen: perScreen.modelData }
            }
        }
    }

    LockScreen {}

    // Instantiate singletons that must run from startup.
    Component.onCompleted: {
        Theme.init();
        Notifs.init();
        Idle.init();
    }
}
