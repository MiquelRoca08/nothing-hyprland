// System monitor in the bar. Click: opens btop (floating Alacritty, class TUI.float). On
// hover, a tooltip with CPU and RAM usage and both GPUs: the integrated AMD one (sysfs
// gpu_busy_percent) and the NVIDIA one. For the NVIDIA, nvidia-smi is only queried if it is already active
// (power/runtime_status): calling it while the GPU is idle wakes it up.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

BarText {
    id: root
    text: "󰍛"

    property real cpu: -1          // % (-1 = not measured yet: two readings are needed)
    property var lastCpu: null     // [busy, total] from the previous /proc/stat reading
    property real memUsed: 0       // GiB
    property real memTotal: 0
    property int amd: -1           // % (-1 = no AMD GPU)
    property string nvState: ""    // "active", "suspended"… ("" = no NVIDIA)
    property int nvUse: -1
    property real nvMemUsed: 0     // GiB
    property real nvMemTotal: 0

    function gib(kib) { return kib / 1048576 }

    // A single reading: the cpu line of /proc/stat, memory, AMD and NVIDIA, each with its label
    Process {
        id: proc
        command: ["sh", "-c",
            "echo \"cpu $(head -1 /proc/stat | cut -c5-)\"; " +
            "awk '/^MemTotal|^MemAvailable/ {printf \"%s \", $2} END {print \"\"}' /proc/meminfo | sed 's/^/mem /'; " +
            "for c in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$c\" ] && echo \"amd $(cat $c)\" && break; done; " +
            "for d in /sys/bus/pci/devices/*; do " +
            "[ \"$(cat $d/vendor)\" = 0x10de ] && case $(cat $d/class) in 0x0300*|0x0302*) " +
            "s=$(cat $d/power/runtime_status); echo \"nvs $s\"; " +
            "[ \"$s\" = active ] && echo \"nv $(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | tr -d ,)\"; " +
            "break;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.nvUse = -1
                for (const line of text.trim().split("\n")) {
                    const f = line.trim().split(/\s+/), k = f.shift(), n = f.map(Number)
                    if (k === "cpu") {
                        // user nice system idle iowait irq softirq steal: free = idle + iowait
                        const total = n.slice(0, 8).reduce((a, b) => a + b, 0), busy = total - n[3] - n[4]
                        if (root.lastCpu && total > root.lastCpu[1])
                            root.cpu = 100 * (busy - root.lastCpu[0]) / (total - root.lastCpu[1])
                        root.lastCpu = [busy, total]
                    } else if (k === "mem") {
                        root.memTotal = root.gib(n[0])
                        root.memUsed = root.gib(n[0] - n[1])
                    } else if (k === "amd") {
                        root.amd = n[0]
                    } else if (k === "nvs") {
                        root.nvState = f[0]
                    } else if (k === "nv") {
                        root.nvUse = n[0]
                        root.nvMemUsed = n[1] / 1024
                        root.nvMemTotal = n[2] / 1024
                    }
                }
            }
        }
    }
    Timer {
        interval: 1500; repeat: true; triggeredOnStart: true
        running: hover.hovered
        onTriggered: proc.running = true
        onRunningChanged: if (!running) { root.lastCpu = null; root.cpu = -1 }
    }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["alacritty", "--class", "TUI.float", "-e", "btop"])
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
                    BarText {
                        text: "󰻠  CPU  " + (root.cpu < 0 ? "…" : Math.round(root.cpu) + " %")
                        color: root.cpu >= 90 ? Theme.red : Theme.fg
                    }
                    BarText {
                        visible: root.memTotal > 0
                        readonly property real pct: 100 * root.memUsed / Math.max(1, root.memTotal)
                        text: "󰘚  RAM  " + root.memUsed.toFixed(1) + " / " + root.memTotal.toFixed(1)
                              + " GiB (" + Math.round(pct) + " %)"
                        color: pct >= 90 ? Theme.red : Theme.fg
                    }
                    BarText {
                        visible: root.amd >= 0
                        text: "󰢮  GPU AMD  " + root.amd + " %"
                    }
                    BarText {
                        visible: root.nvState !== ""
                        text: "󰢮  GPU NVIDIA  " + (root.nvUse >= 0
                              ? root.nvUse + " % · " + root.nvMemUsed.toFixed(1) + " / " + root.nvMemTotal.toFixed(1) + " GiB"
                              : root.nvState === "suspended" ? I18n.tr("idle") : "…")
                        color: root.nvUse >= 0 ? Theme.fg : Theme.dim
                    }
                }
            }
        }
    }
}
