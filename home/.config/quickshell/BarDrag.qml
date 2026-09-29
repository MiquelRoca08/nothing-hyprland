// Dragging a bar module to move it somewhere else. It goes inside the module
// (BarDrag { key: "tray"; panel: bar }); the rest (copy, line and where it lands) is done by Bar.qml.
// A DragHandler only activates past the drag threshold: the module's clicks work as before.
import QtQuick

DragHandler {
    id: root
    required property string key
    required property var panel    // the bar (Bar.qml); «bar» would clash with its id
    target: null
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.ClosedHandCursor

    onActiveChanged: {
        parent.opacity = active ? 0.3 : 1
        if (active) panel.startDrag(key, parent, centroid.scenePressPosition.x)
        else panel.endDrag()
    }
    onCentroidChanged: if (active) panel.moveDrag(centroid.scenePosition.x)
}
