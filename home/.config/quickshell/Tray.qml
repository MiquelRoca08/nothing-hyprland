// Collapsible system tray: a bar button that opens a panel with
// the icons. Click: activate the app. Right click: its menu. Hidden if empty.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

BarText {
    id: root
    readonly property var items: SystemTray.items.values
    property bool open: false
    property bool menuOpen: false     // with a menu open the panel does not close
    property string hovered: ""

    text: (open ? "󰅃" : "󰅀") + " " + items.length
    color: open ? Theme.fg : Theme.dim

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }

    LazyLoader {
        active: root.open

        PopupWindow {
            id: popup
            visible: true
            anchor {
                item: root
                edges: Edges.Bottom
                gravity: Edges.Bottom
                adjustment: PopupAdjustment.SlideX
                // The icon is centred on the bar: the panel starts right below it
                rect.y: (Theme.barHeight + root.height) / 2
            }
            implicitWidth: Math.max(grid.implicitWidth, label.implicitWidth) + 24
            implicitHeight: body.implicitHeight + 24
            color: "transparent"

            HyprlandFocusGrab {
                active: !root.menuOpen
                windows: [popup]
                onCleared: root.open = false
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 10

                    Grid {
                        id: grid
                        Layout.alignment: Qt.AlignHCenter
                        columns: Math.min(5, root.items.length)
                        spacing: 2

                        Repeater {
                            model: root.items

                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                width: 30
                                height: 30
                                radius: 8
                                color: area.containsMouse ? Theme.surface : "transparent"

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 16
                                    source: cell.modelData.icon
                                }

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: root.hovered = containsMouse
                                        ? (cell.modelData.tooltipTitle || cell.modelData.title || cell.modelData.id) : ""
                                    onClicked: mouse => {
                                        const it = cell.modelData
                                        if (mouse.button === Qt.LeftButton && !it.onlyMenu) {
                                            it.activate()
                                            root.open = false
                                        } else if (it.hasMenu) {
                                            root.menuOpen = true
                                            menu.open()
                                        }
                                    }
                                }

                                QsMenuAnchor {
                                    id: menu
                                    menu: cell.modelData.menu
                                    anchor.item: cell
                                    anchor.edges: Edges.Bottom
                                    anchor.gravity: Edges.Bottom
                                    onClosed: { root.menuOpen = false; root.open = false }
                                }
                            }
                        }
                    }

                    // Name of the app under the pointer
                    BarText {
                        id: label
                        Layout.alignment: Qt.AlignHCenter
                        text: root.hovered || I18n.tr("Tray")
                        color: root.hovered ? Theme.fg : Theme.dim
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
