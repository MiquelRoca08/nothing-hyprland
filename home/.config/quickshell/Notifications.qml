// Notification server with popups at the top right (focused screen).
// Click a notification to dismiss it. History and Do Not Disturb: Settings →
// Notifications (and the bell button in the bar).
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        // Everything goes to the history; the popup is skipped in Do Not Disturb (except critical ones)
        onNotification: n => {
            ShellState.addNotification({ app: n.appName, summary: n.summary, body: n.body,
                                         icon: n.appIcon, time: Date.now() })
            if (!Config.options.dnd || n.urgency === NotificationUrgency.Critical) n.tracked = true
        }
    }

    PanelWindow {
        screen: ShellState.focusedScreen
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        margins { top: Theme.gap; right: Theme.gap }
        implicitWidth: 380
        implicitHeight: list.implicitHeight
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-notifications"

        ColumnLayout {
            id: list
            width: parent.width
            spacing: Theme.gap

            Repeater {
                model: server.trackedNotifications.values

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: content.implicitHeight + 24
                    radius: Theme.cardRadius
                    color: Theme.bg
                    border.width: 1
                    border.color: modelData.urgency === NotificationUrgency.Critical ? Theme.red : Theme.border

                    // Timeout: the one the app asks for (ms; some send seconds) or 6 s.
                    // Critical ones do not expire on their own.
                    Timer {
                        readonly property real t: card.modelData.expireTimeout
                        interval: t > 0 ? (t < 1000 ? t * 1000 : t) : 6000
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        onTriggered: card.modelData.expire()
                    }

                    TapHandler { onTapped: card.modelData.dismiss() }

                    RowLayout {
                        id: content
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignTop
                            visible: source != ""
                            source: card.modelData.image || (card.modelData.appIcon ? Quickshell.iconPath(card.modelData.appIcon, true) : "")
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(80, 80)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            BarText {
                                Layout.fillWidth: true
                                text: card.modelData.appName
                                color: Theme.dim
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            BarText {
                                Layout.fillWidth: true
                                text: card.modelData.summary
                                font.bold: true
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            BarText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: card.modelData.body
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                            Row {
                                visible: card.modelData.actions.length > 0
                                spacing: 6
                                Repeater {
                                    model: card.modelData.actions
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: label.implicitWidth + 20
                                        implicitHeight: 26
                                        radius: 8
                                        color: Theme.surface
                                        BarText { id: label; anchors.centerIn: parent; text: modelData.text; font.pixelSize: 12 }
                                        TapHandler { onTapped: modelData.invoke() }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
