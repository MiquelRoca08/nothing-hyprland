// Default speaker volume. Click: sound panel. Right click: mute. Wheel: up/down.
import Quickshell.Services.Pipewire
import QtQuick

BarText {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    PwObjectTracker { objects: [root.sink] }

    text: (muted ? "󰝟" : vol > 0.6 ? "󰕾" : vol > 0.25 ? "󰖀" : "󰕿") + " " + Math.round(vol * 100) + "%"
    color: muted ? Theme.dim : Theme.fg

    BarHover {}
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) panel.open = !panel.open
            else if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        }
        onWheel: wheel => {
            if (!root.sink?.audio) return
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step))
        }
    }

    SoundPanel {
        id: panel
        anchorItem: root
    }
}
