// Bar button that opens Settings.
import QtQuick

BarText {
    text: "󰒓"
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
    }
}
