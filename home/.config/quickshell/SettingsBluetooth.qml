// Settings → Bluetooth: turn on/off, scan, pair, connect and forget.
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: "Bluetooth"
    subtitle: I18n.tr("Pair, connect and disconnect devices")
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: (adapter?.devices?.values ?? [])
        .slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || "").localeCompare(b.name || ""))

    // Turn on/off. If rfkill has it blocked, BlueZ will not turn it on:
    // it has to be unblocked first (the user has permission on /dev/rfkill).
    // Turning it off blocks it again, like other desktops (saves power and
    // systemd-rfkill keeps the state across reboots).
    readonly property bool blocked: adapter?.state === BluetoothAdapterState.Blocked
    function setPower(on) {
        if (on) {
            unblockProc.running = true
        } else {
            if (adapter) adapter.enabled = false
            Quickshell.execDetached(["rfkill", "block", "bluetooth"])
        }
    }
    Process {
        id: unblockProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: powerOn.restart()
    }
    Timer { id: powerOn; interval: 400; onTriggered: if (page.adapter) page.adapter.enabled = true }

    // Stop scanning when leaving the page
    Component.onDestruction: if (adapter?.discovering) adapter.discovering = false

    SettingsGroup {
        SettingsRow {
            text: "Bluetooth"
            description: !page.adapter ? I18n.tr("No adapter")
                       : page.adapter.enabled ? I18n.tr("On")
                       : page.blocked ? I18n.tr("Off (blocked)") : I18n.tr("Off")
            Toggle {
                visible: !!page.adapter
                checked: page.adapter?.enabled ?? false
                onToggled: page.setPower(!(page.adapter?.enabled ?? false))
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("Devices")
        visible: page.adapter?.enabled ?? false

        RowLayout {
            Layout.fillWidth: true
            BarText { text: I18n.tr("Click to connect or disconnect"); color: Theme.dim; font.pixelSize: 11; Layout.fillWidth: true }
            Button {
                icon: page.adapter?.discovering ? "󰓛" : "󰑐"
                text: page.adapter?.discovering ? I18n.tr("Stop scanning") : I18n.tr("Scan")
                onClicked: page.adapter.discovering = !page.adapter.discovering
            }
        }

        BarText { visible: page.devices.length === 0; text: I18n.tr("No devices. Press Scan."); color: Theme.dim }

        Repeater {
            model: page.devices
            delegate: Rectangle {
                id: dev
                required property var modelData
                readonly property bool busy: modelData.pairing
                    || modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 8
                color: hover.hovered || modelData.connected ? Theme.control : "transparent"
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 10
                    BarText { text: "󰂯"; color: dev.modelData.connected ? Theme.fg : Theme.dim }
                    BarText {
                        Layout.fillWidth: true
                        text: dev.modelData.name || dev.modelData.address
                        elide: Text.ElideRight
                        font.bold: dev.modelData.connected
                    }
                    BarText {
                        visible: dev.modelData.batteryAvailable
                        text: "󰁹 " + Math.round(dev.modelData.battery * 100) + "%"
                        color: Theme.dim
                        font.pixelSize: 11
                    }
                    BarText {
                        text: dev.busy ? "…" : dev.modelData.connected ? I18n.tr("Connected") : dev.modelData.paired ? I18n.tr("Paired") : ""
                        color: Theme.dim
                        font.pixelSize: 11
                    }
                    IconButton { visible: dev.modelData.paired; danger: true; onClicked: dev.modelData.forget() }
                }

                TapHandler {
                    onTapped: {
                        const d = dev.modelData
                        if (dev.busy) return
                        if (d.connected) d.disconnect()
                        else if (d.paired) d.connect()
                        else { d.trusted = true; d.pair() }
                    }
                }
            }
        }
    }
}
