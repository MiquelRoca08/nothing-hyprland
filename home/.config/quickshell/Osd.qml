// Floating volume and brightness indicator (bottom, focused screen).
// Volume: detects PipeWire changes by itself. Brightness: the keybind notifies it with
// `qs ipc call osd brightness` (sysfs emits no change events).
// Brightness is read with scripts/brightness.sh (it picks the right backlight).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: root
    property string icon: ""
    property real value: 0
    property bool shown: false
    property bool ready: false        // show nothing on startup

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source] }

    function show(icon, value) {
        if (!ready) return
        root.icon = icon
        root.value = Math.max(0, Math.min(1, value))
        root.shown = true
        hideTimer.restart()
    }
    function showVolume() {
        const a = root.sink?.audio
        if (!a) return
        show(a.muted ? "󰝟" : a.volume > 0.6 ? "󰕾" : a.volume > 0.25 ? "󰖀" : "󰕿", a.muted ? 0 : a.volume)
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.showVolume() }
        function onMutedChanged() { root.showVolume() }
    }

    // Microphone: only on mute or unmute (its volume is rarely changed and needs no notice)
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() {
            const a = root.source.audio
            root.show(a.muted ? "󰍭" : "󰍬", a.muted ? 0 : a.volume)
        }
    }

    Process {
        id: briProc
        command: [Quickshell.shellPath("scripts/brightness.sh"), "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = parseInt(text)
                if (!isNaN(pct)) root.show("󰃠", pct / 100)
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brightness(): void { briProc.running = true }
    }

    Timer { interval: 2000; running: true; onTriggered: root.ready = true }
    Timer { id: hideTimer; interval: 1500; onTriggered: root.shown = false }

    LazyLoader {
        active: root.shown

        PanelWindow {
            screen: ShellState.focusedScreen
            anchors.bottom: true
            margins.bottom: 60
            implicitWidth: 280
            implicitHeight: 52
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "qs-osd"

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                RowLayout {
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    spacing: 12

                    BarText { text: root.icon; font.pixelSize: 20 }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.surface
                        Rectangle {
                            width: parent.width * root.value
                            height: parent.height
                            radius: 3
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 80 } }
                        }
                    }

                    BarText {
                        text: Math.round(root.value * 100)
                        font.family: Theme.displayFont
                        font.pixelSize: 20
                        font.weight: Font.Black
                        Layout.preferredWidth: 42
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
