// Slider. Emits moved(value) while dragging; the value is up to whoever uses it.
import QtQuick

Item {
    id: root
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0
    signal moved(real value)

    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    implicitWidth: 240
    implicitHeight: 24

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.control
        Rectangle { width: parent.width * root.frac; height: parent.height; radius: 3; color: Theme.sel }
    }
    Rectangle {
        x: (root.width - width) * root.frac
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16; radius: 8
        color: Theme.fg
        border.color: Theme.sel
        border.width: 2
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(x) {
            let v = root.from + Math.max(0, Math.min(1, x / width)) * (root.to - root.from)
            if (root.stepSize > 0) v = Math.round(v / root.stepSize) * root.stepSize
            root.moved(v)
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x) }
    }
}
