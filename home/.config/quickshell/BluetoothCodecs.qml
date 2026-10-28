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
    // LHDC (Savitech, e.g. Nothing Ear): the device offers it, but Arch's PipeWire has no
    // plugin for it; it comes with the optional «lhdc» feature (features.txt)
    property bool deviceLhdc: false
    property bool lhdcPlugin: false
    readonly property bool hasLhdc: music.some(o => /LHDC/i.test(o.label))
    readonly property string lhdcInstall: "yay -S --needed liblhdcv5 pipewire-bluez5-lhdc-git wireplumber-lhdc-config"
        + " && systemctl --user daemon-reload && systemctl --user restart wireplumber"
    spacing: 8

    function reload() { listProc.running = true; lhdcProc.running = true }
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

    // Device endpoints (their A2DP capabilities: vendor codecs start with the vendor id, Savitech
    // 0x053a = «58 5 0 0») and whether the LHDC plugin is installed
    Process {
        id: lhdcProc
        command: ["sh", "-c",
            "for s in $(busctl tree --list org.bluez | grep \"/dev_$1/sep[0-9]*$\"); do " +
            "busctl get-property org.bluez \"$s\" org.bluez.MediaEndpoint1 Capabilities; done; " +
            "ls /usr/lib/spa-0.2*/bluez5/libspa-codec-bluez5-lhdc.so 2>/dev/null",
            "_", root.address.replace(/:/g, "_")]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n")
                root.deviceLhdc = lines.some(l => /^ay \d+ 58 5 0 0\b/.test(l))
                root.lhdcPlugin = lines.some(l => l.endsWith("lhdc.so"))
            }
        }
    }
    // After the install terminal: reread
    Connections {
        target: ShellState
        function onSettingsChanged() { root.reload() }
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
    // The device has LHDC but it is not offered: missing plugin, or WirePlumber/the device
    // has not picked it up yet
    RowLayout {
        visible: root.deviceLhdc && !root.hasLhdc && root.loaded
        Layout.fillWidth: true
        spacing: 12
        BarText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.lhdcPlugin
                ? I18n.tr("LHDC is installed: disconnect and reconnect the device to use it.")
                : I18n.tr("This device supports LHDC, but PipeWire needs its plugin (optional LHDC feature).")
            color: Theme.fgSoft
            font.pixelSize: 11
        }
        Button {
            visible: !root.lhdcPlugin
            icon: "󰏗"
            text: I18n.tr("Install LHDC")
            onClicked: Terminal.run("LHDC", root.lhdcInstall)
        }
    }

    BarText {
        visible: root.music.length + root.calls.length > 0
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: I18n.tr("Music codecs sound better (LDAC, LHDC, AAC, SBC-XQ > SBC); call profiles enable the microphone at lower quality.")
        color: Theme.dim
        font.pixelSize: 11
    }
}
