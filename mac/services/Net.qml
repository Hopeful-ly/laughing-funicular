pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager state via nmcli (reactive through `nmcli monitor`).
Singleton {
    id: root
    property bool wifiEnabled: true
    property string ssid: ""
    property int signal: 0
    property bool wired: false
    property bool online: ssid !== "" || wired
    property var networks: []          // [{ ssid, signal, secure, active, known }]
    property bool scanning: false
    property string connecting: ""
    property string lastError: ""
    property var known: []

    function refresh() { statusProc.running = true; }
    function scan() { scanning = true; listProc.command = ["bash", "-c", "nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list --rescan yes"]; listProc.running = true; }
    function setWifi(on) { wifiEnabled = on; Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]); }
    function connect(ssidName, password) {
        connecting = ssidName; lastError = "";
        if (known.indexOf(ssidName) >= 0 && !password) connectProc.command = ["nmcli", "con", "up", "id", ssidName];
        else if (password) connectProc.command = ["nmcli", "dev", "wifi", "connect", ssidName, "password", password];
        else connectProc.command = ["nmcli", "dev", "wifi", "connect", ssidName];
        connectProc.running = true;
    }
    function disconnect() { Quickshell.execDetached(["bash", "-c", "nmcli con down id \"$(nmcli -t -f NAME,TYPE con show --active | grep wireless | head -1 | cut -d: -f1)\""]); }

    function icon() {
        if (wired && ssid === "") return "lan";
        if (!wifiEnabled) return "wifi_off";
        if (ssid === "") return "wifi_find";
        if (signal > 66) return "wifi";
        if (signal > 33) return "wifi_2_bar";
        return "wifi_1_bar";
    }

    Process {
        id: statusProc
        command: ["bash", "-c", "nmcli -t radio wifi; echo ---; nmcli -t -f TYPE,STATE dev; echo ---; nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan no | grep '^yes' | head -1; echo ---; nmcli -t -f NAME,TYPE con show | grep wireless | cut -d: -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n");
                root.wifiEnabled = (parts[0] || "").trim() === "enabled";
                root.wired = (parts[1] || "").split("\n").some(l => l.startsWith("ethernet:connected"));
                const act = (parts[2] || "").trim();
                if (act) {
                    const f = act.split(":");
                    root.signal = +f[1];
                    root.ssid = f.slice(2).join(":");
                } else { root.ssid = ""; root.signal = 0; }
                root.known = (parts[3] || "").split("\n").filter(s => s);
            }
        }
    }
    Process {
        id: listProc
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SIGNAL,SECURITY,SSID dev wifi list --rescan no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const f = line.replace(/\\:/g, "\u0001").split(":");
                    const name = (f[3] || "").replace(/\u0001/g, ":");
                    if (!name || seen[name]) continue;
                    seen[name] = true;
                    out.push({ ssid: name, signal: +f[1], secure: f[2] !== "" && f[2] !== "--", active: f[0] === "yes", known: root.known.indexOf(name) >= 0 });
                }
                out.sort((a, b) => (b.active - a.active) || (b.known - a.known) || (b.signal - a.signal));
                root.networks = out;
                root.scanning = false;
            }
        }
    }
    Process {
        id: connectProc
        stderr: StdioCollector { onStreamFinished: if (text.trim()) root.lastError = text.trim() }
        onExited: code => { root.connecting = ""; if (code !== 0 && !root.lastError) root.lastError = "Could not connect"; root.refresh(); }
    }

    // React to NetworkManager changes, debounced.
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: debounce.restart() }
    }
    Timer { id: debounce; interval: 400; onTriggered: { root.refresh(); if (root.networks.length) listProc.running = true; } }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
