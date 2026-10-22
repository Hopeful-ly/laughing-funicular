pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale state + fast user switching via the `tailscale` CLI
// (needs `sudo tailscale set --operator=$USER` once). Reactive through `tailscale debug watch-ipn`.
Singleton {
    id: root
    property string state: ""          // BackendState: Running · Stopped · NeedsLogin · Starting · "" (unavailable)
    readonly property bool available: state !== ""
    readonly property bool up: state === "Running"
    property bool denied: false        // operator not set
    property var accounts: []          // [{ id, nickname, tailnet, account, selected }]
    readonly property var current: accounts.find(a => a.selected) || null
    property string hostname: ""
    property string ip: ""
    property var peers: []             // [{ id, name, dns, ip, os, online, exitOption, exitActive }]
    readonly property var exitNodes: peers.filter(p => p.exitOption)
    readonly property var exitNode: peers.find(p => p.exitActive) || null
    property var prefs: ({})           // RouteAll, CorpDNS, ExitNodeAllowLANAccess, ShieldsUp …
    property string busy: ""           // label of the running action
    property string error: ""

    // Browser sign-in (add account / re-auth)
    readonly property bool signingIn: loginProc.running
    property string authUrl: ""
    property string prevAccount: ""

    function refresh() { statusProc.running = true; listProc.running = true; prefsProc.running = true; }

    function label(a) { return a ? (a.tailnet || a.account) : ""; }
    function sublabel(a) { return !a ? "" : a.tailnet === a.account ? "Personal tailnet" : a.account; }
    function stateText() {
        if (!available) return "Unavailable";
        if (signingIn) return "Waiting for sign-in…";
        switch (state) {
        case "Running": return exitNode ? "Connected · via " + exitNode.name : "Connected";
        case "Stopped": return "Disconnected";
        case "NeedsLogin": return "Signed out";
        case "NeedsMachineAuth": return "Awaiting admin approval";
        case "Starting": return "Connecting…";
        default: return state;
        }
    }

    // done(code, stdout) may override failure; return true to treat the run as successful.
    function act(name, cmd, done) {
        if (actProc.running) return;
        busy = name; error = "";
        actProc.done = done || null;
        actProc.command = ["tailscale"].concat(cmd);
        actProc.running = true;
    }
    function setUp(on) {
        if (on && (state === "NeedsLogin" || !current)) return signIn(["up"]);
        act(on ? "Connecting" : "Disconnecting", [on ? "up" : "down"]);
    }
    function toggle() { setUp(!up); }
    // `switch` exits 1 whenever the account it lands on isn't running yet, even though the switch
    // itself worked — so check the outcome instead of the exit code, and connect a stopped account
    // like picking one in the Tailscale app does.
    function switchTo(id) {
        if (current && current.id === id) return;
        act("Switching account", ["switch", id], () => { verifyProc.target = id; verifyProc.running = true; return true; });
    }
    function remove(id) { act("Removing account", ["switch", "remove", id]); }
    function logout() { act("Logging out", ["logout"]); }
    function setExitNode(ipOrEmpty) { act("Changing exit node", ["set", "--exit-node=" + ipOrEmpty]); }
    function setPref(flag, on) { act("Updating settings", ["set", "--" + flag + "=" + on]); }

    // `tailscale login` adds a new profile and blocks until the browser flow completes.
    function addAccount() { signIn(["login"]); }
    function signIn(cmd) {
        if (loginProc.running) return;
        prevAccount = current ? current.id : "";
        authUrl = ""; error = "";
        loginProc.command = ["tailscale"].concat(cmd);
        loginProc.running = true;
    }
    function openAuthUrl() { if (authUrl) Qt.openUrlExternally(authUrl); }
    function cancelSignIn() {
        if (!loginProc.running) return;
        loginProc.cancelled = true;
        loginProc.running = false;
    }
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]); }
    function adminConsole() { Qt.openUrlExternally("https://login.tailscale.com/admin/machines"); }

    function cleanErr(t) { return t.split("\n").filter(l => l.trim() && !l.startsWith("Warning: client version")).join(" ").trim(); }

    Process {
        id: statusProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s;
                try { s = JSON.parse(text); } catch (e) { root.state = ""; return; }
                root.state = s.BackendState || "";
                if (s.AuthURL && root.signingIn && !root.authUrl) { root.authUrl = s.AuthURL; root.openAuthUrl(); }
                root.hostname = s.Self ? s.Self.HostName : "";
                root.ip = s.Self && s.Self.TailscaleIPs ? s.Self.TailscaleIPs[0] : "";
                const out = [];
                for (const k in (s.Peer || {})) {
                    const p = s.Peer[k];
                    out.push({
                        id: p.ID, name: (p.DNSName || "").split(".")[0] || p.HostName, dns: (p.DNSName || "").replace(/\.$/, ""),
                        ip: p.TailscaleIPs ? p.TailscaleIPs[0] : "", os: p.OS || "", online: !!p.Online,
                        exitOption: !!p.ExitNodeOption, exitActive: !!p.ExitNode
                    });
                }
                out.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
                root.peers = out;
            }
        }
        onExited: code => { if (code !== 0) root.state = ""; }
    }
    Process {
        id: listProc
        command: ["tailscale", "switch", "--list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.accounts = JSON.parse(text) || []; root.denied = false; } catch (e) {}
            }
        }
        stderr: StdioCollector { onStreamFinished: root.denied = text.indexOf("access denied") >= 0 }
    }
    Process {
        id: prefsProc
        command: ["tailscale", "debug", "prefs"]
        stdout: StdioCollector { onStreamFinished: { try { root.prefs = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: actProc
        property var done: null
        // stdout must be read: unread, the pipe closes and the CLI dies of SIGPIPE on its first print.
        stdout: StdioCollector { id: actOut }
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            const ok = done ? done(code, actOut.text) : code === 0;
            if (!ok) root.error = root.cleanErr(actErr.text) || root.cleanErr(actOut.text) || root.busy + " failed";
            root.busy = "";
            root.refresh();
        }
    }
    Process {
        id: verifyProc
        property string target: ""
        command: ["sh", "-c", "sleep 0.4; tailscale switch --list --json 2>/dev/null; printf '\\036'; tailscale status --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\u001e");
                let accts = [], st = "";
                try { accts = JSON.parse(parts[0]); st = JSON.parse(parts[1]).BackendState || ""; } catch (e) {}
                const sel = accts.find(a => a.selected);
                if (!sel || sel.id !== verifyProc.target) root.error = "Couldn’t switch account";
                else if (st === "Stopped") root.act("Connecting", ["up"]);
                else if (st === "NeedsLogin") root.error = "This account is signed out — turn Tailscale on to sign in again.";
                root.refresh();
            }
        }
    }
    Process {
        id: loginProc
        property bool cancelled: false
        onRunningChanged: if (running) cancelled = false
        stdout: SplitParser { onRead: l => loginProc.scan(l) }
        stderr: SplitParser { onRead: l => loginProc.scan(l) }
        function scan(l) {
            const m = l.match(/https:\/\/\S+/);
            if (m && !root.authUrl) { root.authUrl = m[0]; root.openAuthUrl(); }
            else if (!m && /error|denied|failed/i.test(l)) root.error = root.cleanErr(l);
        }
        onExited: code => {
            // Abandoned or failed sign-in leaves an empty profile selected — go back to where we were.
            if ((code !== 0 || cancelled) && root.prevAccount) Quickshell.execDetached(["tailscale", "switch", root.prevAccount]);
            if (code !== 0 && !cancelled && !root.error) root.error = "Sign-in failed";
            root.authUrl = "";
            Qt.callLater(root.refresh);
        }
    }

    // React to backend changes (state, prefs, profiles, netmap), debounced.
    Process {
        id: watch
        running: true
        command: ["tailscale", "debug", "watch-ipn", "--peer-patches=false"]
        stdout: SplitParser { onRead: debounce.restart() }
        onExited: rewatch.start()
    }
    Timer { id: rewatch; interval: 5000; onTriggered: watch.running = true }
    Timer { id: debounce; interval: 500; onTriggered: root.refresh() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: refresh()
}
