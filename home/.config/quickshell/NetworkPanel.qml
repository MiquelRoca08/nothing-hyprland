// Wi-Fi panel below the network icon: turn on/off, scan and networks.
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property Item anchorItem
    property bool open: false

    onOpenChanged: if (open) { NetworkService.error = ""; NetworkService.reload() }
    Timer { interval: 8000; running: root.open; repeat: true; onTriggered: NetworkService.reload() }

    LazyLoader {
        active: root.open

        PopupWindow {
            id: popup
            visible: true
            anchor {
                item: root.anchorItem
                edges: Edges.Bottom
                gravity: Edges.Bottom
                adjustment: PopupAdjustment.SlideX
                // The icon is centred on the bar: the panel starts right below it
                rect.y: (Theme.barHeight + root.anchorItem.height) / 2
            }
            implicitWidth: 340
            implicitHeight: body.implicitHeight + 24
            color: "transparent"

            HyprlandFocusGrab {
                active: true
                windows: [popup]
                onCleared: root.open = false
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cardRadius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        BarText { text: "Wi-Fi"; font.bold: true; Layout.fillWidth: true }
                        BarText {
                            text: "󰑐"
                            visible: NetworkService.wifiOn
                            color: NetworkService.scanning ? Theme.dim : Theme.fg
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkService.rescan()
                            }
                        }
                        Toggle {
                            checked: NetworkService.wifiOn
                            onToggled: NetworkService.setWifi(!NetworkService.wifiOn)
                        }
                    }

                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }

                    WifiList { Layout.fillWidth: true }

                    BarText {
                        text: I18n.tr("More settings…")
                        color: Theme.dim
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.open = false; ShellState.openSettings("wifi") }
                        }
                    }
                }
            }
        }
    }
}
