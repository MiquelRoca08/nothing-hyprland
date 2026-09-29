// Full-screen power menu. SUPER+ESCAPE (qs ipc call powermenu toggle).
// Esc or a click outside closes it.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    IpcHandler {
        target: "powermenu"
        function toggle(): void { ShellState.powerMenuOpen = !ShellState.powerMenuOpen }
    }

    LazyLoader {
        active: ShellState.powerMenuOpen

        PanelWindow {
            screen: ShellState.focusedScreen
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#b3000000"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-powermenu"

            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.powerMenuOpen = false
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: ShellState.powerMenuOpen = false
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 20

                Repeater {
                    model: [
                        { icon: "󰌾", label: I18n.tr("Lock"),      cmd: "bloquear" },
                        { icon: "󰍃", label: I18n.tr("Log out"), cmd: "command -v hyprshutdown >/dev/null && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
                        { icon: "󰤄", label: I18n.tr("Suspend"),     cmd: "systemctl suspend" },
                        { icon: "󰜉", label: I18n.tr("Reboot"),     cmd: "systemctl reboot" },
                        { icon: "󰐥", label: I18n.tr("Power off"),        cmd: "systemctl poweroff" },
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 120
                        implicitHeight: 120
                        radius: Theme.cardRadius
                        // on hover, like the chosen option of the menu: red-tinted background and red border
                        color: hover.hovered ? Theme.selSoft : Theme.bg
                        border.color: hover.hovered ? Theme.sel : Theme.border
                        border.width: 1

                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            BarText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.icon
                                font.pixelSize: 40
                                color: hover.hovered ? Theme.sel : Theme.fg
                            }
                            BarText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                            }
                        }

                        TapHandler {
                            onTapped: {
                                ShellState.powerMenuOpen = false
                                Quickshell.execDetached(["sh", "-c", modelData.cmd])
                            }
                        }
                    }
                }
            }
        }
    }
}
