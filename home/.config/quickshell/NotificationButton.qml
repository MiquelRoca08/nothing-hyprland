// Bar bell. Click: history (Settings → Notifications).
// Right click: toggle Do Not Disturb. Dot: unread notifications.
import QtQuick

BarText {
    text: Config.options.dnd ? "󰂛" : "󰂚"
    color: Config.options.dnd ? Theme.dim : Theme.fg

    Rectangle {
        visible: ShellState.unread > 0 && !Config.options.dnd
        width: 6; height: 6; radius: 3
        color: Theme.fg
        anchors { top: parent.top; right: parent.right; topMargin: 1; rightMargin: -3 }
    }
    BarHover {}
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) Config.options.dnd = !Config.options.dnd
            else ShellState.openSettings("notifications")
        }
    }
}
