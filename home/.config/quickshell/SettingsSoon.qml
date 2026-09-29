// Settings → a page that is not done yet: its title and what is planned (the soon field of its
// entry in Config.settingsTree).
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    readonly property var entry: Config.settingsEntry(ShellState.settingsPage)
    title: I18n.tr(entry.label)

    SettingsGroup {
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: label.implicitWidth + 20; implicitHeight: 24
                radius: 12
                color: Theme.selSoft
                border.color: Theme.sel; border.width: 1
                BarText { id: label; anchors.centerIn: parent; text: I18n.tr("COMING SOON"); color: Theme.sel; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
            }
            BarText {
                Layout.fillWidth: true
                text: I18n.tr(page.entry.soon ?? "")
                color: Theme.fgSoft
                wrapMode: Text.Wrap
            }
        }
    }
}
