import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.widgets

// Leaving Deep Focus, on purpose:
//   1. hold Space (or the button) for Config.focusExitHold seconds
//   2. type Config.focusExitPhrase exactly (no pasting)
//   3. wait out Config.focusExitCountdown seconds — Esc at any point stays in focus
// A timed session that has already ended skips all of that: ↵ leaves.
PopupLayer {
    id: fx
    ns: "mac-dialog"
    persistent: true
    panelItem: card
    readonly property string sname: screen ? screen.name : ""
    open: Focus.exitOpen && Focus.active && (Focus.state.monitor === sname || Focus.state.monitor === "")
    onDismissed: stay()

    property int step: 0                 // 0 hold · 1 phrase · 2 countdown · 3 complete
    property real holdProgress: 0
    property bool holding: false
    property int countdown: 0

    function stay() { Focus.exitOpen = false; }
    function resetFlow() {
        step = Focus.complete ? 3 : 0;
        holdProgress = 0; holding = false; phrase.text = "";
        countdown = Config.focusExitCountdown;
    }
    onOpenChanged: if (open) { resetFlow(); keys.forceActiveFocus(); }
    onStepChanged: { if (step === 1) phrase.forceActiveFocus(); else keys.forceActiveFocus(); if (step === 2) countdown = Config.focusExitCountdown; }

    Timer {
        interval: 33; repeat: true
        running: fx.open && fx.step === 0 && fx.holding
        onTriggered: {
            fx.holdProgress = Math.min(1, fx.holdProgress + 0.033 / Math.max(0.5, Config.focusExitHold));
            if (fx.holdProgress >= 1) { fx.holding = false; fx.step = 1; }
        }
    }
    Timer {
        interval: 60; repeat: true
        running: fx.open && fx.step === 0 && !fx.holding && fx.holdProgress > 0
        onTriggered: fx.holdProgress = Math.max(0, fx.holdProgress - 0.08)   // let go: it drains
    }
    Timer {
        interval: 1000; repeat: true
        running: fx.open && fx.step === 2
        onTriggered: { fx.countdown--; if (fx.countdown <= 0) Focus.end(); }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35 * fx.t) }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { fx.stay(); e.accepted = true; return; }
            if (fx.step === 0 && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { if (!e.isAutoRepeat) fx.holding = true; e.accepted = true; }
            else if (fx.step === 3 && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { Focus.end(); e.accepted = true; }
        }
        Keys.onReleased: e => {
            if (fx.step === 0 && !e.isAutoRepeat && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)) { fx.holding = false; e.accepted = true; }
        }
    }

    Glass {
        id: card
        width: 440
        height: col.implicitHeight + 48
        radius: 26
        tint: Theme.glassThick
        anchors.centerIn: parent
        opacity: fx.t
        scale: 0.94 + 0.06 * fx.t

        ColumnLayout {
            id: col
            x: 24; y: 24
            width: card.width - 48
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 40; height: 40; radius: 12
                    color: fx.step === 3 ? Theme.systemGreen : "#ff375f"
                    Sym { anchors.centerIn: parent; name: fx.step === 3 ? "task_alt" : "center_focus_strong"; size: 24; filled: true; color: "white" }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    T { Layout.fillWidth: true; text: fx.step === 3 ? "Session complete" : "Leave Deep Focus?"; font.pixelSize: 16; font.weight: Font.Bold }
                    T {
                        Layout.fillWidth: true
                        text: Focus.appName + " · " + Focus.fmt(Focus.elapsedSec) + (Focus.timed && !Focus.complete ? " of " + Focus.minutes + " min" : "")
                        font.pixelSize: 12; color: Theme.text2
                    }
                }
            }

            // Step indicator
            RowLayout {
                visible: fx.step < 3
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: ["Hold", "Type", "Wait"]
                    Rectangle {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 22; radius: 11
                        color: index === fx.step ? "#ff375f" : index < fx.step ? Qt.rgba(1, 0.216, 0.373, 0.35) : Theme.field
                        T { anchors.centerIn: parent; text: (index + 1) + " · " + modelData; font.pixelSize: 11; font.weight: Font.DemiBold; color: index <= fx.step ? "white" : Theme.text3 }
                    }
                }
            }

            // ---- Step 0: hold ------------------------------------------------
            ColumnLayout {
                visible: fx.step === 0
                Layout.fillWidth: true
                spacing: 10
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Hold Space for " + Config.focusExitHold + " seconds"; font.pixelSize: 13; color: Theme.text2 }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    width: 110; height: 110
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real p: fx.holdProgress
                        onPChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"); ctx.reset();
                            const c = width / 2, r = c - 6;
                            ctx.lineWidth = 6; ctx.lineCap = "round";
                            ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.12)" : "rgba(0,0,0,0.1)";
                            ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke();
                            if (p > 0) {
                                ctx.strokeStyle = "#ff375f";
                                ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * p); ctx.stroke();
                            }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 82; height: 82; radius: 41
                        color: holdMa.pressed || fx.holding ? Qt.rgba(1, 0.216, 0.373, 0.25) : Theme.field
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Sym { anchors.centerIn: parent; name: "front_hand"; size: 32; filled: true; color: fx.holding ? "#ff375f" : Theme.text2 }
                        MouseArea {
                            id: holdMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: fx.holding = true
                            onReleased: fx.holding = false
                            onCanceled: fx.holding = false
                        }
                    }
                }
            }

            // ---- Step 1: phrase ------------------------------------------------
            ColumnLayout {
                visible: fx.step === 1
                Layout.fillWidth: true
                spacing: 8
                T { Layout.fillWidth: true; text: "Type this exactly:"; font.pixelSize: 13; color: Theme.text2 }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: phraseLabel.implicitHeight + 20
                    radius: 10
                    color: Theme.field
                    T {
                        id: phraseLabel
                        x: 12; y: 10; width: parent.width - 24
                        wrapMode: Text.Wrap
                        textFormat: Text.RichText
                        font.pixelSize: 14; font.weight: Font.Medium
                        text: {
                            const want = Config.focusExitPhrase, got = phrase.text;
                            let ok = 0;
                            while (ok < got.length && ok < want.length && got[ok] === want[ok]) ok++;
                            const esc = t => t.replace(/&/g, "&amp;").replace(/</g, "&lt;");
                            const c1 = Theme.systemGreen.toString(), c2 = Theme.text.toString();
                            return `<span style="color:${c1}">${esc(want.slice(0, ok))}</span><span style="color:${c2}">${esc(want.slice(ok))}</span>`;
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 10
                    color: Theme.field
                    border.width: 1.5
                    border.color: phrase.text !== "" && Config.focusExitPhrase.indexOf(phrase.text) !== 0 ? Theme.systemRed : phrase.activeFocus ? Theme.accent : Theme.separator
                    TextInput {
                        id: phrase
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Config.fontFamily
                        font.pixelSize: 14
                        color: Theme.text
                        selectByMouse: false
                        onTextChanged: if (text === Config.focusExitPhrase) fx.step = 2
                        Keys.onPressed: e => {
                            const ctrl = e.modifiers & Qt.ControlModifier, shift = e.modifiers & Qt.ShiftModifier;
                            if (e.key === Qt.Key_Escape) { fx.stay(); e.accepted = true; }
                            else if ((ctrl && (e.key === Qt.Key_V || e.key === Qt.Key_Y)) || (shift && e.key === Qt.Key_Insert)) e.accepted = true;   // no pasting
                        }
                        T { visible: phrase.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Type here…"; font.pixelSize: 14; color: Theme.text3 }
                    }
                    MouseArea { anchors.fill: parent; acceptedButtons: Qt.MiddleButton; onClicked: {} }   // no middle-click paste
                }
            }

            // ---- Step 2: countdown ---------------------------------------------
            ColumnLayout {
                visible: fx.step === 2
                Layout.fillWidth: true
                spacing: 4
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Leaving Deep Focus in"; font.pixelSize: 13; color: Theme.text2 }
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: fx.countdown; font.pixelSize: 56; font.weight: Font.Bold; font.features: { "tnum": 1 } }
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "Changed your mind? Press Esc to stay."; font.pixelSize: 12; color: Theme.text3 }
            }

            // ---- Step 3: complete -------------------------------------------------
            ColumnLayout {
                visible: fx.step === 3
                Layout.fillWidth: true
                spacing: 10
                T { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "You did " + Focus.minutes + " minutes on " + Focus.appName + ". Nice."; font.pixelSize: 13; color: Theme.text2; wrapMode: Text.Wrap }
                Hoverable {
                    Layout.fillWidth: true
                    implicitHeight: 38; radius: 19
                    color: hovered ? Qt.lighter(Theme.systemGreen, 1.1) : Theme.systemGreen
                    T { anchors.centerIn: parent; text: "Leave Deep Focus"; font.pixelSize: 13; font.weight: Font.DemiBold; color: "white" }
                    onClicked: Focus.end()
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Hint { visible: fx.step === 0; label: "Hold"; keys: ["Space"] }
                Hint { visible: fx.step === 3; label: "Leave"; keys: ["↵"] }
                Hint { label: fx.step === 3 ? "Keep going" : "Stay in focus"; keys: ["Esc"]; strong: fx.step !== 3 }
            }
        }
    }
}
