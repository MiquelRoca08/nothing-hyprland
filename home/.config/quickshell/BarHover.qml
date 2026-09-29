// Hover background of a clickable bar module, like Settings' IconButton: a grey rounded box behind
// it (z: -1) that fades in. It goes inside the module (BarHover {}); its HoverHandler is passive,
// so the module's clicks, wheel and dragging (BarDrag) work as before.
import QtQuick

Rectangle {
    property int padX: 7
    property int padY: 5
    readonly property alias hovered: hover.hovered
    anchors { fill: parent; leftMargin: -padX; rightMargin: -padX; topMargin: -padY; bottomMargin: -padY }
    z: -1
    radius: 6
    // at rest, the same color with no opacity (like IconButton), so the animation does not go through black
    color: hover.hovered ? Theme.controlHi : Qt.rgba(Theme.controlHi.r, Theme.controlHi.g, Theme.controlHi.b, 0)
    Behavior on color { ColorAnimation { duration: 100 } }
    HoverHandler { id: hover }
}
