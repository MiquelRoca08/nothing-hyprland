// Button that opens the power menu.
import QtQuick

BarText {
    text: "⏻"
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.powerMenuOpen = true
    }
}
