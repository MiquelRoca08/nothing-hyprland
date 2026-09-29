// Small origin or state tag (AUR, Flatpak, Manual…), in grey.
import QtQuick

Rectangle {
    property alias text: label.text
    implicitWidth: label.implicitWidth + 14
    implicitHeight: 18
    radius: 9
    color: Theme.control
    border.color: Theme.border
    border.width: 1
    BarText { id: label; anchors.centerIn: parent; font.pixelSize: 10; color: Theme.fgSoft }
}
