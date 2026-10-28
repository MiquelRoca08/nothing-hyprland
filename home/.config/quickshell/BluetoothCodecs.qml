// Codec chooser for a connected Bluetooth audio device (headphones, speakers): the
// profiles of its bluez card in PipeWire (pactl). Music = A2DP; calls = HFP/HSP, the
// only ones with a microphone (lower quality). Follows changes made elsewhere (pactl subscribe).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string address: ""
    readonly property string card: "bluez_card." + address.replace(/:/g, "_")
    property var music: []      // [{ v: profile, label: codec }]
    property var calls: []
    property string active: ""
    property bool loaded: false
    spacing: 8

    function reload() { listProc.running = true }
    function choose(profile) {
        if (profile === active) return
        active = profile
        Quickshell.execDetached(["pactl", "set-card-profile", card, profile])
    }

    Component.onCompleted: reload()

    Process {
        id: listProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                let cards = []
                try { cards = JSON.parse(text) } catch (e) {}
                const c = cards.find(c => c.name === root.card)
                const music = [], calls = []
                if (c) {
                    for (const [name, p] of Object.entries(c.profiles || {})) {
                        if (!p.available) continue
                        const isMusic = name.startsWith("a2dp-sink")
                        if (!isMusic && !name.startsWith("headset-head-unit")) continue
                        // «… (A2DP Sink, codec AAC)»; the profile without a suffix is the default codec
                        const m = /codec ([^)]+)\)/.exec(p.description || "")
                        const list = isMusic ? music : calls
                        const label = m ? m[1] : name
                        // The default profile repeats a codec that has its own: keep only one
                        const i = list.findIndex(o => o.label === label)
                        if (i < 0) list.push({ v: name, label: label })
                        else if (name === c.active_profile) list[i].v = name
                    }
                }
                root.music = music
                root.calls = calls
                root.active = c?.active_profile ?? ""
                root.loaded = true
            }
        }
    }

    // Reread when the card changes (another app, auto switch to HFP when the mic is used…)
    Process {
        running: true
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: line => { if (line.includes(" on card ") && !listProc.running) listProc.running = true }
        }
    }

    BarText {
        visible: root.loaded && root.music.length + root.calls.length === 0
        text: I18n.tr("No audio profiles for this device")
        color: Theme.dim
        font.pixelSize: 11
    }

    RowLayout {
        visible: root.music.length > 0
        Layout.fillWidth: true
        spacing: 12
        BarText { text: I18n.tr("Music"); color: Theme.fgSoft; font.pixelSize: 12; Layout.preferredWidth: 130 }
        ChoiceChips {
            Layout.fillWidth: true
            options: root.music
            value: root.active
            onChosen: v => root.choose(v)
        }
    }
    RowLayout {
        visible: root.calls.length > 0
        Layout.fillWidth: true
        spacing: 12
        BarText { text: I18n.tr("Calls (mic)"); color: Theme.fgSoft; font.pixelSize: 12; Layout.preferredWidth: 130 }
        ChoiceChips {
            Layout.fillWidth: true
            options: root.calls
            value: root.active
            onChosen: v => root.choose(v)
        }
    }
    BarText {
        visible: root.music.length + root.calls.length > 0
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: I18n.tr("Music codecs sound better (LDAC, AAC, SBC-XQ > SBC); call profiles enable the microphone at lower quality.")
        color: Theme.dim
        font.pixelSize: 11
    }
}
