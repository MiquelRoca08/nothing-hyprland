// Settings → Notifications: Do Not Disturb and history (ShellState.notifications).
import Quickshell
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: I18n.tr("Notifications")
    subtitle: I18n.tr("Do Not Disturb and this session's history")
    Component.onCompleted: ShellState.unread = 0

    function ago(t) {
        const s = Math.floor((Date.now() - t) / 1000)
        if (s < 60) return I18n.tr("now")
        if (s < 3600) return I18n.tr("%1 min ago").arg(Math.floor(s / 60))
        if (s < 86400) return I18n.tr("%1 h ago").arg(Math.floor(s / 3600))
        return new Date(t).toLocaleString(I18n.locale, "d MMM HH:mm")
    }

    SettingsGroup {
        SettingsRow {
            text: I18n.tr("Do Not Disturb")
            description: I18n.tr("Hides the popups (except critical ones). They are still saved in the history. Also with a right click on the bar's bell.")
            Toggle { checked: Config.options.dnd; onToggled: Config.options.dnd = !Config.options.dnd }
        }
    }

    SettingsGroup {
        label: I18n.tr("History")
        RowLayout {
            Layout.fillWidth: true
            BarText {
                Layout.fillWidth: true
                text: ShellState.notifications.length === 0 ? I18n.tr("No notifications") : I18n.trn(ShellState.notifications.length, "%1 notification", "%1 notifications")
                color: Theme.dim
                font.pixelSize: 11
            }
            Button {
                visible: ShellState.notifications.length > 0
                icon: "󰆴"; text: I18n.tr("Clear all")
                onClicked: ShellState.clearNotifications()
            }
        }

        Repeater {
            model: ShellState.notifications
            delegate: Rectangle {
                id: item
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 20
                radius: 8
                color: hover.hovered ? Theme.control : "transparent"
                HoverHandler { id: hover }

                RowLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 12
                    Image {
                        Layout.preferredWidth: 28; Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignTop
                        visible: source != ""
                        source: item.modelData.icon ? Quickshell.iconPath(item.modelData.icon, true) : ""
                        sourceSize: Qt.size(56, 56)
                        fillMode: Image.PreserveAspectFit
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            BarText { text: item.modelData.app || I18n.tr("App"); color: Theme.dim; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                            BarText { text: ago(item.modelData.time); color: Theme.dim; font.pixelSize: 11 }
                        }
                        BarText { Layout.fillWidth: true; text: item.modelData.summary; font.bold: true; wrapMode: Text.Wrap }
                        BarText {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: item.modelData.body
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.pixelSize: 12
                        }
                    }
                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "󰅖"
                        opacity: hover.hovered ? 1 : 0
                        onClicked: ShellState.removeNotification(item.index)
                    }
                }
            }
        }
    }
}
