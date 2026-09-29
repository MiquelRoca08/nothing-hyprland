// Sound panel below the volume icon: volume and device for output and input, and
// the volume of each app that is playing. Opened by clicking the bar's volume.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property Item anchorItem
    property bool open: false

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    // Apps that are playing: playback streams (recording ones have isSink =
    // false) with some active link. Firefox, e.g., leaves another stream open but stopped (idle)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream && n.isSink
        && Pipewire.linkGroups.values.some(g => g.source === n && g.state === PwLinkState.Active))

    component Heading: BarText {
        font.pixelSize: 11
        color: Theme.dim
        Layout.topMargin: 4
    }

    LazyLoader {
        active: root.open

        PopupWindow {
            id: popup
            visible: true
            anchor {
                item: root.anchorItem
                edges: Edges.Bottom
                gravity: Edges.Bottom
                adjustment: PopupAdjustment.SlideX
                // The icon is centred on the bar: the panel starts right below it
                rect.y: (Theme.barHeight + root.anchorItem.height) / 2
            }
            implicitWidth: 360
            implicitHeight: body.implicitHeight + 24
            color: "transparent"

            PwObjectTracker { objects: root.sinks.concat(root.sources, root.streams) }
            // The links too (separately: streams depends on their state); without tracking them, their state
            // stays «Unlinked»
            PwObjectTracker { objects: Pipewire.linkGroups.values }

            HyprlandFocusGrab {
                active: true
                windows: [popup]
                onCleared: root.open = false
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cardRadius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 8

                    BarText { text: I18n.tr("Sound"); font.bold: true }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

                    Heading { text: I18n.tr("OUTPUT") }
                    SoundVolumeRow { node: Pipewire.defaultAudioSink }
                    SoundDeviceList {
                        visible: root.sinks.length > 1
                        nodes: root.sinks; current: Pipewire.defaultAudioSink; isOutput: true
                        highlight: Theme.surface
                    }

                    Heading { text: I18n.tr("INPUT") }
                    SoundVolumeRow { node: Pipewire.defaultAudioSource; isInput: true }
                    SoundDeviceList {
                        visible: root.sources.length > 1
                        nodes: root.sources; current: Pipewire.defaultAudioSource; isOutput: false
                        highlight: Theme.surface
                    }

                    Heading { text: I18n.tr("APPS"); visible: root.streams.length > 0 }
                    Repeater {
                        model: root.streams
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0
                            BarText {
                                Layout.fillWidth: true
                                text: modelData.properties["application.name"] || modelData.description || modelData.name
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }
                            SoundVolumeRow { node: modelData; icon: "󰎈" }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
                    BarText {
                        text: I18n.tr("More settings…")
                        color: Theme.dim
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.open = false; ShellState.openSettings("sound") }
                        }
                    }
                }
            }
        }
    }
}
