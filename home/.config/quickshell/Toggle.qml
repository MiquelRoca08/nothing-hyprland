// Switch. Emits toggled(); the state is up to whoever uses it (checked).
import QtQuick

Rectangle {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: 11
    color: checked ? Theme.sel : Theme.control
    border.color: Theme.border
    border.width: checked ? 0 : 1

    Rectangle {
        width: 16; height: 16; radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Theme.selText : Theme.fgSoft
        Behavior on x { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
