// Settings → Sound: output and input (device and volume) and the
// microphone test: level meter and live monitoring (pw-loopback).
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Sound")
    subtitle: I18n.tr("Output, input and microphone test")

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    PwObjectTracker { objects: page.sinks.concat(page.sources) }

    // Microphone test: it only measures while active. Leaving the page
    // or closing Settings destroys it and stops everything (monitoring too).
    property bool testing: false
    property bool listening: false
    PwNodePeakMonitor {
        id: micPeak
        node: Pipewire.defaultAudioSource
        enabled: page.testing
    }
    // Linear peak (0–1) → level in dB, from -60 dB (0) to 0 dB (1)
    readonly property real micLevel: page.testing && micPeak.peak > 0
        ? Math.max(0, Math.min(1, (20 * Math.log10(micPeak.peak) + 60) / 60)) : 0
    // Hear yourself: links the default microphone to the default output
    Process {
        running: page.listening
        command: ["pw-loopback", "--name", "qs-mic-test"]
    }

    SettingsGroup {
        label: I18n.tr("Output")
        SoundVolumeRow { node: Pipewire.defaultAudioSink }
        SoundDeviceList { nodes: page.sinks; current: Pipewire.defaultAudioSink; isOutput: true }
    }

    SettingsGroup {
        label: I18n.tr("Input")
        SettingsRow {
            text: I18n.tr("Mute the microphone")
            description: Pipewire.defaultAudioSource?.audio?.muted
                ? I18n.tr("Nobody can hear you. Also with the bar's microphone or the mic mute key.")
                : I18n.tr("Also with the bar's microphone or the mic mute key.")
            Toggle {
                checked: Pipewire.defaultAudioSource?.audio?.muted ?? false
                enabled: !!Pipewire.defaultAudioSource?.audio
                onToggled: { const a = Pipewire.defaultAudioSource?.audio; if (a) a.muted = !a.muted }
            }
        }
        SoundVolumeRow { node: Pipewire.defaultAudioSource; isInput: true }
        SoundDeviceList { nodes: page.sources; current: Pipewire.defaultAudioSource; isOutput: false }
    }

    SettingsGroup {
        label: I18n.tr("Microphone test")

        SettingsRow {
            text: I18n.tr("Measure the level")
            description: I18n.tr("Speak and watch how much the meter moves.")
            Toggle { checked: page.testing; onToggled: page.testing = !page.testing }
        }

        // Meter: a row of dots that light up with the level
        Row {
            id: meter
            readonly property int count: 32
            readonly property int lit: Math.round(page.micLevel * count)
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            spacing: 4
            opacity: page.testing ? 1 : 0.4
            Repeater {
                model: meter.count
                delegate: Rectangle {
                    required property int index
                    width: (meter.width - meter.spacing * (meter.count - 1)) / meter.count
                    height: 14
                    radius: Math.min(width, height) / 2
                    // The last dots warn of clipping
                    color: index >= meter.lit ? Theme.control
                         : index >= meter.count - 3 ? Theme.red : Theme.fg
                    Behavior on color { ColorAnimation { duration: 60 } }
                }
            }
        }

        SettingsRow {
            text: I18n.tr("Hear myself")
            description: I18n.tr("Sends the microphone to the output so you hear yourself live. Use headphones: with speakers it feeds back.")
            Toggle { checked: page.listening; onToggled: page.listening = !page.listening }
        }
    }
}
