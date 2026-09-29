// Settings → Power: profile (power-profiles-daemon), battery and charge limit (asusctl).
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Battery")
    subtitle: I18n.tr("Power profile, battery state and charge limit")
    readonly property var bat: UPower.displayDevice
    property int chargeLimit: 0

    function duration(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? `${h} h ${m} min` : `${m} min`
    }

    Process {
        id: limitGet
        running: true
        command: ["asusctl", "battery", "info"]
        stdout: StdioCollector {
            onStreamFinished: { const m = text.match(/(\d+)%/); if (m) page.chargeLimit = parseInt(m[1]) }
        }
    }
    Process {
        id: limitSet
        onExited: limitGet.running = true
    }

    SettingsGroup {
        label: I18n.tr("Power profile")
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { p: PowerProfile.PowerSaver,  icon: "󰌪", label: I18n.tr("Power saver") },
                    { p: PowerProfile.Balanced,    icon: "󰾅", label: I18n.tr("Balanced") },
                    { p: PowerProfile.Performance, icon: "󱐋", label: I18n.tr("Performance") },
                ]
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool selected: PowerProfiles.profile === modelData.p
                    visible: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: 12
                    color: selected ? (tileHover.hovered ? Theme.selHi : Theme.sel) : tileHover.hovered ? Theme.controlHi : Theme.control
                    border.color: Theme.border
                    border.width: selected ? 0 : 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    HoverHandler { id: tileHover }
                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; font.pixelSize: 20; color: selected ? Theme.selText : Theme.fg }
                        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: selected ? Theme.selText : Theme.fg }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PowerProfiles.profile = modelData.p }
                }
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("Battery")
        visible: page.bat?.isLaptopBattery ?? false
        SettingsRow {
            text: Math.round((page.bat?.percentage ?? 0) * 100) + "%"
            description: page.bat?.state === UPowerDeviceState.Charging ? I18n.tr("Charging") + (page.duration(page.bat.timeToFull) ? " · " + I18n.tr("full in %1").arg(page.duration(page.bat.timeToFull)) : "")
                       : page.bat?.state === UPowerDeviceState.FullyCharged ? I18n.tr("Fully charged")
                       : page.bat?.state === UPowerDeviceState.Discharging ? I18n.tr("On battery") + (page.duration(page.bat.timeToEmpty) ? " · " + I18n.tr("%1 left").arg(page.duration(page.bat.timeToEmpty)).toLowerCase() : "")
                       : I18n.tr("Plugged in")
            BarText {
                visible: (page.bat?.changeRate ?? 0) > 0
                text: (page.bat?.changeRate ?? 0).toFixed(1) + " W"
                color: Theme.dim
            }
        }
        SettingsRow {
            text: I18n.tr("Charge limit")
            description: I18n.tr("Charging only up to this level extends the battery's life (asusctl)")
            ChoiceChips {
                value: page.chargeLimit
                options: [{ v: 60, label: "60%" }, { v: 80, label: "80%" }, { v: 100, label: "100%" }]
                onChosen: v => { limitSet.command = ["asusctl", "battery", "limit", String(v)]; limitSet.running = true }
            }
        }
    }
}
