// Settings group: small label and a card with the content.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string label: ""
    default property alias content: card.data
    Layout.fillWidth: true
    spacing: 6

    BarText {
        visible: root.label !== ""
        text: root.label.toUpperCase()
        color: Theme.dim
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.2
        Layout.leftMargin: 4
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: card.implicitHeight + 32
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.control
        border.width: 1

        ColumnLayout {
            id: card
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 14
        }
    }
}
