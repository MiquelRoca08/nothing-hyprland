// Base of a Settings page: header (the section icon in red, title and optional
// subtitle) and a content column. The icon comes from Config.settingsTree (current page).
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title: ""
    property string subtitle: ""
    spacing: 16

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 14
        Rectangle {
            implicitWidth: 40; implicitHeight: 40
            radius: 12
            color: Theme.selSoft
            BarText {
                anchors.centerIn: parent
                text: Config.settingsEntry(ShellState.settingsPage).icon
                font.pixelSize: 20
                color: Theme.sel
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            BarText { text: root.title; font.pixelSize: 22; font.bold: true }
            BarText {
                visible: root.subtitle !== ""
                text: root.subtitle
                color: Theme.dim
                font.pixelSize: 12
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
