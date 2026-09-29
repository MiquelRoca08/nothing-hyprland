// MPRIS player in the bar: controls and title of the one being controlled (chosen
// by MediaService). Click on the title: panel with the track and the sources.
// Hidden if there are no players.
import Quickshell
import QtQuick

Row {
    id: root
    readonly property var player: MediaService.player
    readonly property int maxTextWidth: 320

    property bool enabledInBar: true
    visible: enabledInBar && player !== null
    spacing: 10

    component Button: BarText {
        property bool active: true
        signal clicked
        color: active ? Theme.fg : Theme.dim
        font.pixelSize: 15
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            enabled: parent.active
            onClicked: parent.clicked()
        }
    }

    Button {
        text: "󰒮"
        active: root.player?.canGoPrevious ?? false
        onClicked: root.player.previous()
    }
    Button {
        text: root.player?.isPlaying ? "󰏤" : "󰐊"
        active: root.player?.canTogglePlaying ?? false
        onClicked: root.player.togglePlaying()
    }
    Button {
        text: "󰒭"
        active: root.player?.canGoNext ?? false
        onClicked: root.player.next()
    }

    BarText {
        id: title
        width: Math.min(implicitWidth, root.maxTextWidth)
        elide: Text.ElideRight
        text: {
            const p = root.player
            if (!p) return ""
            const title = p.trackTitle || p.identity || ""
            return p.trackArtist ? `${title}  ·  ${p.trackArtist}` : title
        }
        color: root.player?.isPlaying ? Theme.fg : Theme.dim
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.open = !panel.open
        }
        MediaPanel {
            id: panel
            anchorItem: title
        }
    }
}
