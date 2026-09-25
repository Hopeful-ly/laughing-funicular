pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root
    readonly property var players: Mpris.players.values
    property var manual: null
    readonly property var player: {
        if (manual && players.indexOf(manual) >= 0) return manual;
        return players.find(p => p.isPlaying) || players[0] || null;
    }
    readonly property bool active: player !== null && player.trackTitle !== ""
}
