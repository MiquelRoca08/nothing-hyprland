// Button that opens the power menu.
import QtQuick

BarText {
    text: "⏻"
    BarHover {}
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.powerMenuOpen = true
    }
}
