pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / temperature / fan / battery health / power profile.
// Cheap stats are read straight from /proc and /sys (no process spawn) every
// 2 s; top processes and frequency are only sampled while the panel is open.
Singleton {
    id: root

    property bool detailed: false          // set by the System panel while open

    // ---- CPU -------------------------------------------------------------
    property real cpu: 0                   // 0..1
    property var cores: []                 // [0..1]
    property var history: []               // last 60 cpu samples
    property var _prev: null
    property real temp: -1                 // °C, -1 = unavailable
    property int fan: -1                   // RPM, -1 = unavailable
    property real freq: 0                  // GHz, average
    property string load: ""
    property string model: ""
    property int nproc: 0
    property var top: []                   // [{ pid, name, cpu, mem }]

    // ---- Memory ------------------------------------------------------------
    property real memUsed: 0               // GiB
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0

    // ---- Battery extras ---------------------------------------------------
    property real health: -1               // full / design, 0..1
    property int cycles: -1
    property int chargeLimit: 100

    // ---- Disks ---------------------------------------------------------------
    // [{ dev, fs, mount, size, used, avail }] one per real block device (btrfs
    // subvolumes collapse into their shortest mount point).
    property var disks: []
    readonly property var mainDisk: disks.find(d => d.mount === "/") || disks[0] || null
    property bool diskDetailed: false      // set by the Disk panel while open
    property var spaceHogs: []             // [{ label, path, bytes, action }]
    property bool scanning: false
    function refreshDisks() { dfProc.running = true; }
    function scanHogs() { if (!duProc.running) { scanning = true; duProc.running = true; } }
    function human(b) {
        if (b < 0) return "—";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++; }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=source,fstype,target,size,used,avail", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const byDev = {};
                for (const l of text.split("\n").slice(1)) {
                    const p = l.trim().split(/\s+/);
                    if (p.length < 6 || !p[0].startsWith("/dev/")) continue;
                    const mount = p.slice(2, p.length - 3).join(" ");
                    const d = { dev: p[0], fs: p[1], mount: mount, size: +p[p.length - 3], used: +p[p.length - 2], avail: +p[p.length - 1] };
                    const cur = byDev[d.dev];
                    if (!cur || d.mount.length < cur.mount.length) byDev[d.dev] = d;
                }
                root.disks = Object.values(byDev).sort((a, b) => (a.mount === "/" ? -1 : b.mount === "/" ? 1 : b.size - a.size));
            }
        }
    }
    Timer { interval: root.diskDetailed ? 5000 : 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshDisks() }
    Process {
        id: duProc
        command: ["bash", "-c",
            "s(){ [ -e \"$2\" ] && echo \"$1|$2|$(timeout 8 du -sxb \"$2\" 2>/dev/null | cut -f1)\"; };" +
            "s Trash ~/.local/share/Trash; s Downloads ~/Downloads; s 'User cache' ~/.cache; s 'Package cache' /var/cache/pacman/pkg;" +
            "s Steam ~/.local/share/Steam; s Docker ~/.local/share/docker; s 'Flatpak' ~/.local/share/flatpak; s 'Journal logs' /var/log/journal"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.spaceHogs = text.split("\n").filter(l => l).map(l => {
                    const p = l.split("|");
                    return { label: p[0], path: p[1], bytes: p[2] === "" ? -1 : +p[2] };
                }).filter(x => x.bytes !== 0).sort((a, b) => b.bytes - a.bytes);
                root.scanning = false;
            }
        }
    }

    // ---- Power profile ------------------------------------------------------
    property string profile: ""
    property var profiles: []
    readonly property bool hasProfiles: profiles.length > 0
    function setProfile(p) { profile = p; Quickshell.execDetached(["powerprofilesctl", "set", p]); }
    function cycleProfile() {
        if (!hasProfiles) return;
        const i = profiles.indexOf(profile);
        setProfile(profiles[(i + 1) % profiles.length]);
    }

    function tempColor(t) { return t >= 85 ? Theme.systemRed : t >= 70 ? Theme.systemOrange : Theme.text; }

    // ---- Sources --------------------------------------------------------
    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: mem; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: loadavg; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: tempFile; path: root.tempPath; blockLoading: true }
    FileView { id: fanFile; path: root.fanPath; blockLoading: true }
    FileView { id: cpuinfo; path: "/proc/cpuinfo"; blockLoading: true }
    property string tempPath: ""
    property string fanPath: ""

    function parseStat() {
        const lines = stat.text().split("\n").filter(l => l.startsWith("cpu"));
        const cur = lines.map(l => {
            const f = l.split(/\s+/).slice(1, 9).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            return { idle: idle, total: total };
        });
        if (_prev && _prev.length === cur.length) {
            const u = cur.map((c, i) => {
                const dt = c.total - _prev[i].total, di = c.idle - _prev[i].idle;
                return dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0;
            });
            cpu = u[0];
            cores = u.slice(1);
            const h = history.concat([u[0]]);
            history = h.length > 60 ? h.slice(h.length - 60) : h;
        }
        _prev = cur;
        nproc = cur.length - 1;
    }
    function parseMem() {
        const m = {};
        for (const l of mem.text().split("\n")) {
            const p = l.split(/:\s+/);
            if (p.length > 1) m[p[0]] = parseInt(p[1]);
        }
        const g = 1024 * 1024;
        memTotal = (m.MemTotal || 0) / g;
        memUsed = ((m.MemTotal || 0) - (m.MemAvailable || 0)) / g;
        swapTotal = (m.SwapTotal || 0) / g;
        swapUsed = ((m.SwapTotal || 0) - (m.SwapFree || 0)) / g;
    }
    function parseCpuinfo() {
        const mhz = cpuinfo.text().split("\n").filter(l => l.startsWith("cpu MHz")).map(l => parseFloat(l.split(":")[1]));
        if (mhz.length) freq = mhz.reduce((a, b) => a + b, 0) / mhz.length / 1000;
        if (!model) {
            const m = cpuinfo.text().match(/model name\s*:\s*(.+)/);
            if (m) model = m[1].replace(/\(R\)|\(TM\)|CPU|@.*$/g, "").replace(/\s+/g, " ").trim();
        }
    }

    function sample() {
        stat.reload(); parseStat();
        mem.reload(); parseMem();
        loadavg.reload(); load = loadavg.text().split(" ").slice(0, 3).join("  ");
        if (tempPath) { tempFile.reload(); const t = parseInt(tempFile.text()); temp = isNaN(t) ? -1 : t / 1000; }
        if (fanPath) { fanFile.reload(); const f = parseInt(fanFile.text()); fan = isNaN(f) ? -1 : f; }
        if (detailed) { cpuinfo.reload(); parseCpuinfo(); topProc.running = true; }
    }
    Timer { interval: root.detailed ? 1000 : 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }

    // Find the package temperature sensor + fan once.
    Process {
        running: true
        command: ["bash", "-c",
            "for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type); case $t in x86_pkg_temp|TCPU|k10temp|cpu-thermal|acpitz) echo \"temp $t $z/temp\";; esac; done;" +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name); [ \"$n\" = coretemp ] || [ \"$n\" = k10temp ] && echo \"temp $n $h/temp1_input\"; ls $h/fan*_input 2>/dev/null | head -1 | sed 's/^/fan /'; done;" +
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -n \"$b\" ]; then f=$(cat $b/energy_full $b/charge_full 2>/dev/null | head -1); d=$(cat $b/energy_full_design $b/charge_full_design 2>/dev/null | head -1); echo \"bat $f $d $(cat $b/cycle_count 2>/dev/null || echo -1) $(cat $b/charge_control_end_threshold 2>/dev/null || echo 100)\"; fi;" +
            "echo \"prof $(powerprofilesctl get 2>/dev/null) $(powerprofilesctl list 2>/dev/null | grep -oE '^[* ] +[a-z-]+:' | tr -d '*: ' | tr '\\n' ' ')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const pref = ["x86_pkg_temp", "k10temp", "coretemp", "TCPU", "cpu-thermal", "acpitz"];
                let best = null;
                for (const l of text.split("\n")) {
                    const p = l.trim().split(/\s+/);
                    if (p[0] === "temp") {
                        const r = pref.indexOf(p[1]);
                        if (!best || r < best.r) best = { r: r, path: p[2] };
                    } else if (p[0] === "fan" && p[1] && !root.fanPath) root.fanPath = p[1];
                    else if (p[0] === "bat") {
                        const f = +p[1], d = +p[2];
                        if (f > 0 && d > 0) root.health = Math.min(1, f / d);
                        root.cycles = +p[3] > 0 ? +p[3] : -1;
                        root.chargeLimit = +p[4] || 100;
                    } else if (p[0] === "prof") {
                        root.profile = p[1] || "";
                        root.profiles = p.slice(2).filter(x => x).reverse();   // power-saver, balanced, performance
                    }
                }
                if (best) root.tempPath = best.path;
            }
        }
    }

    Process {
        id: topProc
        command: ["bash", "-c", "ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu | head -6"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.top = text.split("\n").filter(l => l.trim()).map(l => {
                    const p = l.trim().split(/\s+/);
                    return { pid: p[0], name: p.slice(1, p.length - 2).join(" "), cpu: +p[p.length - 2], mem: +p[p.length - 1] };
                }).filter(x => x.name !== "ps");
            }
        }
    }
}
