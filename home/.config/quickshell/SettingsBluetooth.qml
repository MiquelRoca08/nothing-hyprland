// Settings → Bluetooth: turn on/off, scan, pair, connect and forget; codec of
// connected headphones and speakers (BluetoothCodecs).
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

    // Pairing: trust and connect only once the bond exists. Trusting first
    // left half-known devices when pairing failed (Trusted but not Paired):
    // BlueZ then accepts their connections and drops them at once for lack of
    // keys (a multipoint headset connects and disconnects in a loop).
    // Quickshell has no agent: BlueZ pairs without one (just works), which is
    // what headsets, mice and keyboards without a screen use.
    property var pending: ({})      // address → true while we pair it
    property string failed: ""      // last address that did not pair
    function startPair(d) {
        if (adapter && !adapter.pairable) adapter.pairable = true
        failed = ""
        const p = Object.assign({}, pending); p[d.address] = true; pending = p
        d.pair()
    }
    function pairDone(d, ok) {
        if (!pending[d.address]) return
        const p = Object.assign({}, pending); delete p[d.address]; pending = p
        if (ok) { d.trusted = true; d.connect() }
        else { if (d.trusted) d.trusted = false; failed = d.address }
    }

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
            delegate: ColumnLayout {
                id: dev
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                // Headphones and speakers (BlueZ icon audio-*): codec chooser, folded
                readonly property bool isAudio: (modelData.icon || "").startsWith("audio-")
                property bool expanded: false
                readonly property bool showCodecs: expanded && isAudio && modelData.connected
                readonly property bool busy: modelData.pairing
                    || modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting
                // Known but without keys (left by a failed pairing or a reset
                // on the device's side): it only works after pairing again
                readonly property bool broken: !modelData.paired && (modelData.trusted || modelData.connected)
                readonly property bool didFail: page.failed === modelData.address

                Connections {
                    target: dev.modelData
                    function onPairedChanged() { if (dev.modelData.paired) page.pairDone(dev.modelData, true) }
                    // Pairing ends before Paired arrives: wait a moment before calling it a failure
                    function onPairingChanged() { if (!dev.modelData.pairing) pairCheck.restart() }
                }
                Timer { id: pairCheck; interval: 1500; onTriggered: if (!dev.modelData.paired) page.pairDone(dev.modelData, false) }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 8
                    color: hover.hovered || dev.modelData.connected ? Theme.control : "transparent"
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
                            text: dev.busy ? "…"
                                : dev.didFail ? I18n.tr("Not paired: put it in pairing mode and click again")
                                : dev.broken ? I18n.tr("Click to pair again")
                                : dev.modelData.connected ? I18n.tr("Connected")
                                : dev.modelData.paired ? I18n.tr("Paired") : ""
                            color: dev.didFail || dev.broken ? Theme.red : Theme.dim
                            font.pixelSize: 11
                        }
                        IconButton {
                            visible: dev.isAudio && dev.modelData.connected
                            icon: dev.expanded ? "󰅃" : "󰅀"
                            onClicked: dev.expanded = !dev.expanded
                        }
                        IconButton { visible: dev.modelData.paired || dev.broken; danger: true; onClicked: dev.modelData.forget() }
                    }

                    TapHandler {
                        onTapped: {
                            const d = dev.modelData
                            if (dev.busy) return
                            if (d.paired) { if (d.connected) d.disconnect(); else d.connect() }
                            else {
                                // A device that connects without keys keeps dropping:
                                // let go of it and pair from scratch
                                if (d.connected) d.disconnect()
                                if (d.trusted) d.trusted = false
                                page.startPair(d)
                            }
                        }
                    }
                }

                Loader {
                    active: dev.showCodecs
                    visible: active
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 4
                    sourceComponent: BluetoothCodecs { address: dev.modelData.address }
                }
            }
        }
    }
}
