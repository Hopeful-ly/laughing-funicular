# mac — macOS-style Quickshell for Hyprland

Run with `qs -c mac` (started from `~/.config/hypr/autostart.lua`).
Press **Super + /** for the full, searchable shortcut sheet.

| Piece | File | Opens with |
|---|---|---|
| Menu bar (app, title, occupied workspaces, status items) | `modules/MenuBar.qml` | — |
| Dock (pinned + running, magnify, smart auto-hide) | `modules/Dock.qml` | move to bottom edge |
| Launcher (apps, commands, `=` maths, `/` files, `?` web, `>` shell) | `modules/Launcher.qml` | Super R · Alt Space |
| Clipboard history (paste, pin, delete, filters, save image) | `modules/Clipboard.qml` | Super V |
| Control Center (Wi-Fi, Bluetooth, sound, display, media) | `modules/ControlCenter.qml` | Super A |
| Notification Center + calendar, toasts | `modules/NotificationCenter.qml`, `Toasts.qml` | Super N |
| System panel (battery, power mode, CPU, memory, processes) | `modules/SystemPanel.qml` | click CPU or battery in the bar |
| Lock screen (PAM) | `modules/LockScreen.qml` | Super L |
| Wallpaper picker | launcher view | Super ⇧ W |

Theme: `services/Theme.qml` samples the wallpaper (ImageMagick) for dark/light,
accent and glass tint, and pushes the accent to Hyprland borders.
Settings persist in `~/.local/state/quickshell/by-shell/<id>/settings.json`.

IPC examples:

```sh
qs -c mac ipc call shell toggle launcher     # launcher|clipboard|controlcenter|notifications|shortcuts|wallpapers|windows|calculator|session
qs -c mac ipc call wallpaper set ~/Pictures/wallpapers/walls/macos-sonoma-dark.jpg
qs -c mac ipc call wallpaper random
qs -c mac ipc call lock preview              # show the lock screen without locking
```
