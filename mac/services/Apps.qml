pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop applications: fuzzy search, frecency ranking, launching, icons.
Singleton {
    id: root

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // ---- Frecency --------------------------------------------------------
    FileView {
        id: store
        path: Quickshell.statePath("frecency.json")
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter { id: fdata; property var usage: ({}) }
    }

    function record(key) {
        const u = Object.assign({}, fdata.usage);
        const e = u[key] || { count: 0, last: 0 };
        u[key] = { count: e.count + 1, last: Date.now() };
        fdata.usage = u;
    }
    function forget(key) {
        const u = Object.assign({}, fdata.usage);
        delete u[key];
        fdata.usage = u;
    }
    function frecency(key) {
        const e = fdata.usage[key];
        if (!e) return 0;
        const ageH = (Date.now() - e.last) / 3600000;
        const decay = ageH < 4 ? 1 : ageH < 24 ? 0.8 : ageH < 168 ? 0.55 : 0.3;
        return Math.log2(1 + e.count) * decay;
    }

    // ---- Fuzzy matching --------------------------------------------------
    function fuzzy(text, q) {
        if (!text) return -1;
        const t = text.toLowerCase();
        if (t === q) return 100;
        if (t.startsWith(q)) return 85 - Math.min(10, t.length * 0.15);
        const idx = t.indexOf(q);
        if (idx > 0 && /[\s\-_.\/]/.test(t[idx - 1])) return 70 - idx * 0.2;
        const words = t.split(/[\s\-_.\/]+/).filter(w => w.length);
        const initials = words.map(w => w[0]).join("");
        if (q.length > 1 && initials.startsWith(q)) return 66;
        if (idx >= 0) return 52 - idx * 0.4;
        let from = 0, last = -1, gaps = 0;
        for (const ch of q) {
            const f = t.indexOf(ch, from);
            if (f < 0) return -1;
            if (last >= 0) gaps += f - last - 1;
            last = f; from = f + 1;
        }
        return Math.max(1, 34 - gaps * 1.5);
    }

    function scoreApp(a, q) {
        let s = fuzzy(a.name, q);
        s = Math.max(s, fuzzy(a.genericName, q) * 0.75);
        s = Math.max(s, fuzzy(a.id, q) * 0.6);
        for (const k of a.keywords) s = Math.max(s, fuzzy(k, q) * 0.7);
        return s;
    }

    function search(query, limit) {
        const q = query.trim().toLowerCase();
        if (q === "") return suggestions(limit || 8);
        const out = [];
        for (const a of apps) {
            const s = scoreApp(a, q);
            if (s > 0) out.push({ app: a, score: s + frecency("app:" + a.id) * 6 });
        }
        out.sort((x, y) => y.score - x.score);
        return out.slice(0, limit || 40).map(x => x.app);
    }

    function suggestions(n) {
        const scored = apps.map(a => ({ app: a, f: frecency("app:" + a.id) })).filter(x => x.f > 0);
        scored.sort((x, y) => y.f - x.f);
        return scored.slice(0, n).map(x => x.app);
    }

    // ---- Launch ---------------------------------------------------------
    function launch(a) {
        if (!a) return;
        record("app:" + a.id);
        if (a.runInTerminal)
            Quickshell.execDetached({ command: [Config.terminal, "-e"].concat(a.command), workingDirectory: a.workingDirectory || Quickshell.env("HOME") });
        else
            a.execute();
    }
    function launchAction(a, act) { record("app:" + a.id); act.execute(); }

    // ---- Lookup -------------------------------------------------------------
    function byId(id) { return DesktopEntries.byId(id); }
    function forAppId(appId) {
        if (!appId) return null;
        const e = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        if (e) return e;
        // Fall back to a display-name match ("Telegram" -> org.telegram.desktop).
        const l = appId.toLowerCase();
        return apps.find(a => a.name.toLowerCase() === l || a.name.toLowerCase().startsWith(l + " ")) || null;
    }
    function iconName(entry, appId) {
        if (entry && entry.icon) return entry.icon;
        return appId ? appId.toLowerCase() : "application-x-executable";
    }
    function icon(entry, appId) {
        return Quickshell.iconPath(iconName(entry, appId), "application-x-executable");
    }
    function iconForAppId(appId) { return icon(forAppId(appId), appId); }
    function nameForAppId(appId) {
        const e = forAppId(appId);
        if (e && e.name) return e.name;
        if (!appId) return "";
        const last = appId.split(".").pop();
        return last.charAt(0).toUpperCase() + last.slice(1);
    }
}
