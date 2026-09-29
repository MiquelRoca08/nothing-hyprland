// Small icon-only button (delete, close, remove…): grey at rest; on hover, grey
// background and white icon, or red if it deletes (danger). overlay: with a dark background, to put
// it over an image. It keeps the click (MouseArea): it does not reach what is below. Emits clicked().
import QtQuick

Rectangle {
    id: root
    property string icon: "󰆴"
    property bool danger: false
    property bool overlay: false
    property bool busy: false
    property int size: 28
    // background on hover; over something that is already controlHi (a chip with hover), a lighter one
    property color hoverColor: overlay ? "#e6000000" : Theme.controlHi
    readonly property alias hovered: area.containsMouse
    signal clicked
    implicitWidth: size
    implicitHeight: size
    radius: 6
    // at rest, the same color with no opacity: «transparent» is transparent black and the animation
    // would go through dark grey
    color: area.containsMouse ? hoverColor : overlay ? "#99000000" : Qt.rgba(hoverColor.r, hoverColor.g, hoverColor.b, 0)
    opacity: enabled ? 1 : 0.35
    Behavior on color { ColorAnimation { duration: 100 } }

    BarText {
        anchors.centerIn: parent
        text: root.busy ? "…" : root.icon
        font.pixelSize: Math.round(root.size * 0.5)
        color: area.containsMouse ? (root.danger ? Theme.sel : Theme.fg) : root.overlay ? Theme.fg : Theme.dim
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.busy
        onClicked: root.clicked()
    }
}
