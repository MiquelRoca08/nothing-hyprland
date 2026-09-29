// An app's icon: a name from the icon theme («firefox») or a file path (WebApps and
// TUIs keep theirs in ~/.local/share/applications/icons). If it is not found, a generic one.
// It is an Item with the image inside: in Image, implicitWidth/implicitHeight are read-only.
import Quickshell
import QtQuick

Item {
    id: root
    property string icon: ""
    implicitWidth: 28
    implicitHeight: 28
    Image {
        anchors.fill: parent
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: root.icon.startsWith("/") ? "file://" + root.icon
              : Quickshell.iconPath(root.icon || "application-x-executable", "application-x-executable")
    }
}
