// Network status in the bar. Click: Wi-Fi panel.
import QtQuick

BarText {
    id: root
    text: NetworkService.kind === "wifi"     ? NetworkService.signalIcon(NetworkService.signal) + " " + NetworkService.name
        : NetworkService.kind === "ethernet" ? "󰈀"
        :                                      "󰤮"
    color: NetworkService.kind ? Theme.fg : Theme.dim

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: panel.open = !panel.open
    }

    NetworkPanel {
        id: panel
        anchorItem: root
    }
}
