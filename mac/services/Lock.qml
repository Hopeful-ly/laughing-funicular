pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pam

// Session lock state + PAM authentication (replaces hyprlock).
//   qs -c mac ipc call lock lock      (hypridle lock_cmd, lid switch, Super+L)
Singleton {
    id: root
    property bool locked: false
    property bool previewing: false
    property string password: ""
    property string status: ""         // "", "checking", "failed"
    property int failures: 0
    readonly property string user: Quickshell.env("USER")
    property string realName: user

    function lock() { if (!locked) { password = ""; status = ""; locked = true; } }
    function submit() {
        if (password === "" || pam.active) return;
        status = "checking";
        pam.start();
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) respond(root.password);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.locked = false;
                root.status = "";
                root.failures = 0;
            } else {
                root.status = "failed";
                root.failures++;
            }
            root.password = "";
        }
        onError: { root.status = "failed"; root.password = ""; }
    }

    Process {
        running: true
        command: ["bash", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector { onStreamFinished: { const n = text.trim(); if (n) root.realName = n; } }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function isLocked(): bool { return root.locked; }
        function preview(): void { root.previewing = !root.previewing; }
    }
    GlobalShortcut { name: "lock"; description: "Lock screen"; onPressed: root.lock() }
}
