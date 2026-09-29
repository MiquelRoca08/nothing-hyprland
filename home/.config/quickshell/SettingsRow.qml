// Settings row: text on the left (with an optional description) and the control on the right.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property string text: ""
    property string description: ""
    default property alias control: slot.data
    Layout.fillWidth: true
    spacing: 16

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        BarText { text: root.text; Layout.fillWidth: true }   // lets the column stretch
        BarText {
            visible: root.description !== ""
            text: root.description
            color: Theme.dim
            font.pixelSize: 11
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
    RowLayout {
        id: slot
        Layout.fillWidth: false        // nested layouts stretch by default
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
}
