// Bar button that opens Settings.
import QtQuick

BarText {
    text: "󰒓"
    BarHover {}
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.settingsOpen = !ShellState.settingsOpen
    }
}
