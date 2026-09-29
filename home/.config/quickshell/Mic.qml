// Default microphone. Click: mute / unmute. Right click: sound panel. Wheel: input
// volume. Muted shows in red, so it is obvious nobody can hear you.
import Quickshell.Services.Pipewire
import QtQuick

BarText {
    id: root
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool muted: source?.audio?.muted ?? false

    PwObjectTracker { objects: [root.source] }

    text: muted ? "󰍭" : "󰍬"
    color: muted ? Theme.red : Theme.fg

    BarHover {}
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) panel.open = !panel.open
            else if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted
        }
        onWheel: wheel => {
            if (!root.source?.audio) return
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.source.audio.volume = Math.max(0, Math.min(1, root.source.audio.volume + step))
        }
    }

    SoundPanel {
        id: panel
        anchorItem: root
    }
}
