// Battery (UPower). Hidden if there is no battery. On hover, a tooltip with the time
// left (or until full), the power draw and whether the NVIDIA card (dGPU) is active or idle.
// The dGPU is read from sysfs (power/runtime_status), which does not wake it up (nvidia-smi does).
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

BarText {
    id: root
    readonly property var dev: UPower.displayDevice
    readonly property real pct: dev?.percentage ?? 0
    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
                                  || dev?.state === UPowerDeviceState.FullyCharged
    readonly property var icons: ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    property string dgpu: ""   // "active", "suspended"… ("" = no NVIDIA dGPU)

    text: (charging ? "󰂄" : icons[Math.min(9, Math.floor(pct * 10))]) + " " + Math.round(pct * 100) + "%"
    color: !charging && pct <= 0.15 ? Theme.red : Theme.fg

    // 9 h 45 min / 25 min
    function duration(s) {
        if (!s || s <= 0) return ""
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60)
        return h > 0 ? h + " h " + m + " min" : m + " min"
    }
    readonly property string timeText: {
        if (dev?.state === UPowerDeviceState.FullyCharged) return I18n.tr("Fully charged")
        if (charging) { const t = duration(dev?.timeToFull); return t ? I18n.tr("Full in %1").arg(t) : I18n.tr("Charging") }
        const t = duration(dev?.timeToEmpty)
        return t ? I18n.tr("%1 left").arg(t) : I18n.tr("Estimating time…")
    }

    HoverHandler { id: hover }

    // NVIDIA dGPU state (class 0x0300, vendor 0x10de), only while the tooltip is shown
    Process {
        id: dgpuProc
        command: ["sh", "-c",
            "for d in /sys/bus/pci/devices/*; do " +
            "[ \"$(cat $d/vendor)\" = 0x10de ] && case $(cat $d/class) in 0x0300*|0x0302*) cat $d/power/runtime_status; exit;; esac; " +
            "done"]
        stdout: StdioCollector { onStreamFinished: root.dgpu = text.trim() }
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: hover.hovered
        onTriggered: dgpuProc.running = true
    }

    LazyLoader {
        active: hover.hovered

        PopupWindow {
            visible: true
            anchor {
                item: root
                edges: Edges.Bottom
                gravity: Edges.Bottom
                adjustment: PopupAdjustment.SlideX
                // The icon is centred on the bar: the panel starts right below it
                rect.y: (Theme.barHeight + root.height) / 2
            }
            implicitWidth: info.implicitWidth + 28
            implicitHeight: info.implicitHeight + 20
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: info
                    anchors.centerIn: parent
                    spacing: 4
                    BarText { text: "󰔛  " + root.timeText }
                    BarText {
                        visible: (root.dev?.changeRate ?? 0) > 0
                        text: "󱐋  " + (root.dev?.changeRate ?? 0).toFixed(1) + " W"
                        color: Theme.dim
                    }
                    BarText {
                        visible: root.dgpu !== ""
                        text: "󰢮  " + I18n.tr("NVIDIA GPU: %1").arg(root.dgpu === "active" ? I18n.tr("active") : root.dgpu === "suspended" ? I18n.tr("idle") : root.dgpu)
                        color: root.dgpu === "active" ? Theme.fg : Theme.dim
                    }
                }
            }
        }
    }
}
