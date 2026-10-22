pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon (replaces swaync). Tracked notifications form the
// Notification Center history; `popups` drives the toast stack.
Singleton {
    id: root

    property var popups: []
    property var times: ({})          // notification id -> receive time (ms)
    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length

    function init() {}

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true;
            const t = Object.assign({}, root.times); t[n.id] = Date.now(); root.times = t;
            if ((!Config.dnd && !Focus.active) || n.urgency === NotificationUrgency.Critical) {
                root.popups = [n].concat(root.popups).slice(0, 5);
            }
            n.closed.connect(() => root.removePopup(n));
        }
    }

    function removePopup(n) { popups = popups.filter(p => p !== n); }
    function dismiss(n) { removePopup(n); n.dismiss(); }
    function clearAll() {
        const all = Array.from(list);
        for (const n of all) n.dismiss();
        popups = [];
    }
    function clearApp(appName) {
        for (const n of Array.from(list)) if ((n.appName || "") === appName) n.dismiss();
    }

    // Groups for the Notification Center: [{ app, icon, items: [...] }] newest first.
    readonly property var groups: {
        const map = {};
        const order = [];
        const arr = Array.from(list).reverse();
        for (const n of arr) {
            const key = n.appName || "Notifications";
            if (!map[key]) { map[key] = { app: key, items: [] }; order.push(key); }
            map[key].items.push(n);
        }
        return order.map(k => map[k]);
    }

    function iconFor(n) {
        if (n.image) return n.image;
        if (n.appIcon) return n.appIcon.startsWith("/") || n.appIcon.startsWith("file:") || n.appIcon.startsWith("image:") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        const e = n.desktopEntry ? Apps.byId(n.desktopEntry) : Apps.forAppId(n.appName);
        return Apps.icon(e, n.appName);
    }
    function appIconFor(n) {
        const e = n.desktopEntry ? Apps.byId(n.desktopEntry) : Apps.forAppId(n.appName);
        if (e) return Apps.icon(e, n.appName);
        if (n.appIcon && !n.appIcon.startsWith("/")) return Quickshell.iconPath(n.appIcon, "dialog-information");
        return Quickshell.iconPath("dialog-information");
    }

    // Time since, macOS style ("now", "5m", "2h").
    property real now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() }
}
