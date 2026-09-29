// Settings → Home: what you see when opening Settings. At the top, summary cards (updates,
// battery, disk and network) that lead to their section; in the middle, the tasks (saved in
// ~/.local/share/quickshell/tareas.json, outside the repo: they are personal; Enter adds, the circle
// marks as done, 󰆴 deletes); at the bottom, the machine's information.
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Home")
    subtitle: new Date().toLocaleString(I18n.locale, I18n.tr("dddd, MMMM d"))
    property var info: ({})
    // System age: «2 years and 4 months (since May 1, 2024)»; under a month, in days
    function osAge(t) {
        if (!(t > 0)) return ""
        const a = new Date(t * 1000), n = new Date()
        let m = (n.getFullYear() - a.getFullYear()) * 12 + n.getMonth() - a.getMonth()
        if (n.getDate() < a.getDate()) m--
        const parts = []
        if (m >= 12) parts.push(I18n.trn(Math.floor(m / 12), "%1 year", "%1 years"))
        if (m % 12 > 0) parts.push(I18n.trn(m % 12, "%1 month", "%1 months"))
        const age = parts.length ? parts.join(I18n.tr(" and "))
                                 : I18n.trn(Math.max(0, Math.floor((n - a) / 864e5)), "%1 day", "%1 days")
        return I18n.tr("%1 (since %2)").arg(age).arg(a.toLocaleString(I18n.locale, I18n.tr("MMMM d, yyyy")))
    }
    readonly property var bat: UPower.displayDevice
    Component.onCompleted: UpdateService.check(false)

    Process {
        running: true
        command: ["sh", "-c",
            "echo \"host=$(cat /etc/hostname)\"; " +
            ". /etc/os-release; echo \"os=$PRETTY_NAME\"; " +
            "echo \"kernel=$(uname -r)\"; " +
            "echo \"uptime=$(uptime -p | sed 's/^up //')\"; " +
            // Installation: first line of the pacman log; otherwise, the creation date of /
            "i=$(head -1 /var/log/pacman.log 2>/dev/null | sed -n 's/^\\[\\([^]]*\\)\\].*/\\1/p'); " +
            "{ [ -n \"$i\" ] && t=$(date -d \"$i\" +%s 2>/dev/null); } || t=$(stat -c %W / 2>/dev/null); echo \"installed=$t\"; " +
            "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\"; " +
            "echo \"cores=$(nproc)\"; " +
            "lspci -mm | grep -E 'VGA|3D|Display' | cut -d'\"' -f6 | sed 's/^/gpu=/'; " +
            "free -b | awk '/^Mem:/ {printf \"ram=%.1f / %.1f GB\\n\", $3/1e9, $2/1e9}'; " +
            "df -B1 / | awk 'NR==2 {printf \"disk=%.0f / %.0f GB (%s)\\n\", $3/1e9, $2/1e9, $5; printf \"diskpct=%s\\n\", $5}'; " +
            "echo \"hyprland=$(hyprctl version -j | jq -r .tag)\"; " +
            "echo \"quickshell=$(qs --version | head -1 | awk '{print $2}')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = { gpu: [] }
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=")
                    if (i < 0) continue
                    const k = line.slice(0, i), v = line.slice(i + 1)
                    if (k === "gpu") d.gpu.push(v); else d[k] = v
                }
                page.info = d
            }
        }
    }

    // --- Tasks ---
    readonly property string dir: Quickshell.env("HOME") + "/.local/share/quickshell"
    readonly property var pending: store.tasks.filter(t => !t.done)
    readonly property var done: store.tasks.filter(t => t.done)

    // The adapter's lists do not notify if changed inside: they are always reassigned.
    // Each task is identified by `created` (ms): the one coming from a row is a copy
    // (the Repeater's modelData), so comparing it with === never finds the original
    function add(text) {
        const t = text.trim()
        if (!t) return
        let created = Date.now()
        while (store.tasks.some(x => x.created === created)) created++
        store.tasks = store.tasks.concat([{ text: t, done: false, created: created }])
    }
    function toggle(task) { store.tasks = store.tasks.map(t => t.created === task.created ? Object.assign({}, t, { done: !t.done }) : t) }
    function remove(task) { store.tasks = store.tasks.filter(t => t.created !== task.created) }
    function clearDone() { store.tasks = store.tasks.filter(t => !t.done) }

    // The folder has to exist before writing the file
    Process {
        running: true
        command: ["mkdir", "-p", page.dir]
        onExited: file.path = page.dir + "/tareas.json"
    }
    FileView {
        id: file
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }
        JsonAdapter {
            id: store
            property var tasks: []   // [{ text, done, created }]
        }
    }

    // Summary card: red icon, large figure and label; leads to the `target` section
    component Tile: Rectangle {
        id: tile
        property string icon
        property string value
        property string label
        property string target
        property bool alert: false          // figure in red (there is something to do)
        Layout.fillWidth: true
        implicitHeight: 112
        radius: Theme.cardRadius
        color: tileHover.hovered ? Theme.control : Theme.surface
        border.color: tileHover.hovered ? Theme.sel : Theme.control
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }
        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ShellState.settingsPage = tile.target }
        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 4
            Rectangle {
                implicitWidth: 30; implicitHeight: 30; radius: 9
                color: Theme.selSoft
                BarText { anchors.centerIn: parent; text: tile.icon; color: Theme.sel; font.pixelSize: 15 }
            }
            Item { Layout.fillHeight: true }
            BarText {
                text: tile.value
                font.family: Theme.displayFont
                font.pixelSize: 22
                font.weight: Font.Black
                color: tile.alert ? Theme.sel : Theme.fg
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            BarText { text: tile.label; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Tile {
            icon: "󰚰"; target: "updates"
            value: UpdateService.checking ? "…" : String(UpdateService.total)
            label: UpdateService.checking ? I18n.tr("Checking") : UpdateService.total === 0 ? I18n.tr("Up to date") : I18n.tr("Updates")
            alert: !UpdateService.checking && UpdateService.total > 0
        }
        Tile {
            visible: page.bat?.isLaptopBattery ?? false
            icon: page.bat?.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"; target: "battery"
            value: Math.round((page.bat?.percentage ?? 0) * 100) + "%"
            label: page.bat?.state === UPowerDeviceState.Charging ? I18n.tr("Charging")
                 : page.bat?.state === UPowerDeviceState.Discharging ? I18n.tr("On battery") : I18n.tr("Plugged in")
            alert: (page.bat?.percentage ?? 1) < 0.15 && page.bat?.state === UPowerDeviceState.Discharging
        }
        Tile {
            icon: "󰋊"; target: "storage"
            value: page.info.diskpct ?? "…"
            label: I18n.tr("Disk used")
            alert: parseInt(page.info.diskpct ?? "0") >= 90
        }
        Tile {
            icon: NetworkService.kind === "ethernet" ? "󰈀" : "󰤨"; target: "wifi"
            value: NetworkService.kind ? (NetworkService.kind === "wifi" ? NetworkService.signal + "%" : "OK") : "—"
            label: NetworkService.name || I18n.tr("Not connected")
            alert: !NetworkService.kind
        }
    }

    SettingsGroup {
        label: page.pending.length ? I18n.tr("Tasks (%1)").arg(page.pending.length) : I18n.tr("Tasks")
        WifiField {
            id: input
            Layout.fillWidth: true
            placeholder: I18n.tr("New task and Enter")
            onAccepted: { page.add(text); text = "" }
            onCancelled: text = ""
        }
        BarText {
            visible: page.pending.length === 0
            text: I18n.tr("Nothing pending")
            color: Theme.dim
        }
        Repeater {
            model: page.pending
            delegate: TaskRow { required property var modelData; task: modelData }
        }
    }

    SettingsGroup {
        visible: page.done.length > 0
        label: I18n.tr("Done (%1)").arg(page.done.length)
        Repeater {
            model: page.done
            delegate: TaskRow { required property var modelData; task: modelData }
        }
        Button { kind: "ghost"; icon: "󰆴"; text: I18n.tr("Delete done"); onClicked: page.clearDone() }
    }

    // Row of a task
    component TaskRow: RowLayout {
        id: row
        property var task
        Layout.fillWidth: true
        spacing: 10

        BarText {
            text: row.task.done ? "󰄲" : "󰄱"
            color: row.task.done ? Theme.sel : Theme.fgSoft
            MouseArea {
                anchors.fill: parent; anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: page.toggle(row.task)
            }
        }
        BarText {
            Layout.fillWidth: true
            text: row.task.text
            wrapMode: Text.Wrap
            color: row.task.done ? Theme.dim : Theme.fg
            font.strikeout: row.task.done
        }
        IconButton { danger: true; onClicked: page.remove(row.task) }
    }

    component InfoRow: SettingsRow {
        id: infoRow
        property string value
        BarText { text: infoRow.value || "…"; color: Theme.fgSoft; horizontalAlignment: Text.AlignRight; Layout.maximumWidth: 380; elide: Text.ElideRight }
    }

    SettingsGroup {
        label: I18n.tr("Machine")
        InfoRow { text: I18n.tr("Name"); value: page.info.host ?? "" }
        InfoRow { text: I18n.tr("System"); value: page.info.os ?? "" }
        InfoRow { text: "Kernel"; value: page.info.kernel ?? "" }
        InfoRow { text: I18n.tr("System age"); value: page.osAge(parseInt(page.info.installed)) }
        InfoRow { text: I18n.tr("Uptime"); value: page.info.uptime ?? "" }
        InfoRow { text: I18n.tr("Processor"); value: page.info.cpu ? I18n.tr("%1 (%2 threads)").arg(page.info.cpu).arg(page.info.cores) : "" }
        Repeater {
            model: page.info.gpu ?? []
            delegate: InfoRow { required property string modelData; text: I18n.tr("GPU"); value: modelData }
        }
        InfoRow { text: I18n.tr("Memory"); value: page.info.ram ?? "" }
        InfoRow { text: I18n.tr("Disk (/)"); value: page.info.disk ?? "" }
        InfoRow { text: "Hyprland · Quickshell"; value: page.info.hyprland ? `${page.info.hyprland} · ${page.info.quickshell}` : "" }
    }
}
