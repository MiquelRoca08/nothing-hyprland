// Volume row of a PipeWire node: icon (click: mute) + slider with the %.
// Used by Settings → Sound and the bar's sound panel. isInput: microphone icons.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    property var node
    property bool isInput: false
    property string icon: ""           // custom icon (e.g. an app's); otherwise, the usual one
    Layout.fillWidth: true
    spacing: 12

    BarText {
        text: row.node?.audio?.muted ? (row.isInput ? "󰍭" : "󰝟")
            : row.icon || (row.isInput ? "󰍬" : "󰕾")
        font.pixelSize: 16
        color: row.node?.audio?.muted ? Theme.dim : Theme.fg
        Layout.preferredWidth: 18
        MouseArea {
            anchors.fill: parent; anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: if (row.node?.audio) row.node.audio.muted = !row.node.audio.muted
        }
    }
    SliderField {
        fill: true
        from: 0; to: 100
        suffix: "%"
        value: Math.round((row.node?.audio?.volume ?? 0) * 100)
        onMoved: v => { if (row.node?.audio) row.node.audio.volume = v / 100 }
    }
}
