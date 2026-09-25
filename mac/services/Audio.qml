pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks) }

    function setVolume(v) { if (ready) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1.0, v)); } }
    function toggleMute() { if (ready) sink.audio.muted = !sink.audio.muted; }
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }
    function icon() {
        if (muted || volume <= 0.001) return "volume_off";
        if (volume < 0.34) return "volume_mute";
        if (volume < 0.67) return "volume_down";
        return "volume_up";
    }
    function nodeName(n) { return n ? (n.description || n.nickname || n.name) : ""; }
}
