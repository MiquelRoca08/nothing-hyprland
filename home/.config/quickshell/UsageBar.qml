// Usage bar (disk, folders, apps): value from 0 to 1. White; red from
// critical on (e.g. an almost full disk). To pick a value use Slider, not this.
import QtQuick

Rectangle {
    id: root
    property real value: 0
    property real critical: 2          // > 1: never red
    implicitWidth: 200
    implicitHeight: 8
    radius: height / 2
    color: Theme.control
    Rectangle {
        width: Math.max(root.value > 0 ? root.height : 0, root.width * Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.value >= root.critical ? Theme.sel : Theme.fg
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
}
