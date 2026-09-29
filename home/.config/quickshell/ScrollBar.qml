// Scroll bar for a Flickable (put it on top, with flick: the Flickable): thin, it
// widens on hover; the thumb can be dragged and a click on the track jumps there. It only
// shows if there is more content than space.
import QtQuick

Item {
    id: root
    property Flickable flick
    readonly property real ratio: flick && flick.contentHeight > 0 ? Math.min(1, flick.height / flick.contentHeight) : 1
    readonly property real maxY: flick ? Math.max(0, flick.contentHeight - flick.height) : 0
    readonly property bool active: hover.hovered || drag.active
    visible: ratio < 1
    width: 14

    // Track (only on hover)
    Rectangle {
        anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: 8; radius: 4
        color: Theme.control
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    // Thumb
    Rectangle {
        id: thumb
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.active ? 8 : 4
        radius: width / 2
        height: Math.max(32, root.height * root.ratio)
        y: root.maxY > 0 ? (root.height - height) * (root.flick.contentY / root.maxY) : 0
        color: drag.active ? Theme.sel : root.active ? Theme.fgSoft : Theme.dim
        Behavior on width { NumberAnimation { duration: 120 } }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    // Drag the thumb (or from any point of the track)
    DragHandler {
        id: drag
        target: null
        property real startY: 0
        property real startPress: 0
        yAxis.enabled: true; xAxis.enabled: false
        onActiveChanged: if (active) { startY = root.flick.contentY; startPress = centroid.pressPosition.y }
        onCentroidChanged: if (active) {
            const room = root.height - thumb.height
            if (room > 0) root.flick.contentY = Math.max(0, Math.min(root.maxY,
                startY + (centroid.position.y - startPress) / room * root.maxY))
        }
    }
    // Click on the track: the thumb jumps there (centred)
    TapHandler {
        onTapped: event => {
            const room = root.height - thumb.height
            if (room > 0) root.flick.contentY = Math.max(0, Math.min(root.maxY,
                (event.position.y - thumb.height / 2) / room * root.maxY))
        }
    }
}
