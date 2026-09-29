// Settings button. kind: "primary" (red, the main action of a block), "secondary"
// (grey, the rest) or "ghost" (text only, minor actions such as «Reset»). Emits clicked().
import QtQuick

Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string kind: "secondary"
    property bool busy: false          // shows «…» and does not respond
    signal clicked
    readonly property bool primary: kind === "primary"
    readonly property bool ghost: kind === "ghost"
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + (ghost ? 12 : 28))
    implicitHeight: 32
    radius: Theme.controlRadius
    color: ghost ? "transparent"
         : primary ? (hover.hovered ? Theme.selHi : Theme.sel)
         : hover.hovered ? Theme.controlHi : Theme.control
    border.width: primary || ghost ? 0 : 1
    border.color: Theme.border
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 100 } }

    BarText {
        id: label
        anchors.centerIn: parent
        text: root.busy ? "…" : root.icon && root.text ? root.icon + "  " + root.text : root.icon || root.text
        font.pixelSize: 12
        color: root.primary ? Theme.selText : root.ghost ? (hover.hovered ? Theme.fg : Theme.dim) : Theme.fg
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: !root.busy; onTapped: root.clicked() }
}
