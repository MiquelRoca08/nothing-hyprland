// Settings → System → Storage: mounted disks with their usage, what can be freed
// (pacman and yay caches, trash, journal, orphans, unused Flatpak), the apps that
// take the most space (with «Manage», which leads to Installed apps with the app selected) and the
// folders in ~ from largest to smallest (click: they open). Data from scripts/almacenamiento.sh; each
// part in its own process, because the folders (du) are slow. What needs sudo goes to the terminal.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Storage")
    subtitle: I18n.tr("What takes up the disk and what can be freed")

    readonly property string script: Quickshell.shellPath("scripts/almacenamiento.sh")
    property var disks: []          // [{ mount, dev, fs, size, used, free }]
    property var clean: ({})        // { key: bytes } (+ huerfanosN)
    property var apps: []           // [{ name, bytes, aur, flatpak, id }]
    property var folders: []        // [{ path, name, bytes }]
    property bool trashConfirm: false
    property string running: ""     // cleanup running (its button shows busy until it ends)

    function run(key, title, cmd) { running = key; Terminal.run(title, cmd) }
    Connections {
        target: ShellState
        function onSettingsChanged() { page.running = ""; page.load() }
    }

    function load() { disksProc.running = true; cleanProc.running = true; appsProc.running = true; foldersProc.running = true }
    Component.onCompleted: load()

    function fmt(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(b >= 10737418240 ? 0 : 1) + " GB"
        if (b >= 1048576) return Math.round(b / 1048576) + " MB"
        if (b >= 1024) return Math.round(b / 1024) + " KB"
        return b + " B"
    }
    function rows(text, tag) { return text.split("\n").filter(l => l.startsWith(tag + "|")).map(l => l.split("|")) }
    function diskName(m) {
        return m === "/" ? I18n.tr("System") : m === "/boot" || m === "/efi" || m === "/boot/efi" ? I18n.tr("Boot (EFI)")
             : m === "/home" ? I18n.tr("Personal") : m.split("/").pop() || m
    }

    Process {
        id: disksProc
        command: [page.script, "discos"]
        stdout: StdioCollector {
            onStreamFinished: page.disks = page.rows(text, "disco").map(r => (
                { mount: r[1], dev: r[2], fs: r[3], size: +r[4], used: +r[5], free: +r[6] }))
        }
    }
    Process {
        id: cleanProc
        command: [page.script, "limpieza"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = {}
                for (const r of page.rows(text, "limpieza")) { c[r[1]] = +r[2]; if (r[3] !== undefined) c[r[1] + "N"] = +r[3] }
                page.clean = c
            }
        }
    }
    Process {
        id: appsProc
        command: [page.script, "paquetes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = page.rows(text, "paquete").map(r => ({ name: r[1], bytes: +r[2], aur: r[3] === "1", flatpak: false, id: r[1] }))
                    .concat(page.rows(text, "flatpak").map(r => ({ name: r[1], bytes: +r[3], aur: false, flatpak: true, id: r[2] })))
                page.apps = a.sort((x, y) => y.bytes - x.bytes).slice(0, 10)
            }
        }
    }
    Process {
        id: foldersProc
        command: [page.script, "carpetas"]
        stdout: StdioCollector {
            onStreamFinished: page.folders = page.rows(text, "carpeta").map(r => ({ path: r[1], name: r[1].split("/").pop(), bytes: +r[2] }))
        }
    }
    Process { id: trashProc; command: ["gio", "trash", "--empty"]; onExited: cleanProc.running = true }
    // The yay cache belongs to the user: it is emptied without sudo or questions (yay -Sc also asks about
    // pacman's and the repositories)
    Process {
        id: yayProc
        command: ["sh", "-c", 'd="$HOME/.cache/yay"; [ -d "$d" ] && find "$d" -mindepth 1 -delete']
        onExited: cleanProc.running = true
    }

    // Row with a bar: name, detail, size and a bar relative to the largest in the list
    component BarRow: ColumnLayout {
        id: br
        property string label
        property string detail
        property real bytes
        property real max: 1
        property string tag: ""
        default property alias trailing: slot.data
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            BarText { text: br.label; elide: Text.ElideMiddle; Layout.maximumWidth: 260 }
            Tag { visible: br.tag !== ""; text: br.tag }
            BarText { text: br.detail; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
            BarText { text: page.fmt(br.bytes); color: Theme.fgSoft }
            RowLayout { id: slot; spacing: 6 }
        }
        UsageBar { Layout.fillWidth: true; implicitHeight: 4; value: br.max > 0 ? br.bytes / br.max : 0 }
    }

    Button {
        Layout.alignment: Qt.AlignRight
        icon: "󰑐"; text: I18n.tr("Recalculate")
        busy: disksProc.running || cleanProc.running || appsProc.running || foldersProc.running
        onClicked: page.load()
    }

    // --- Disks ---
    SettingsGroup {
        label: I18n.tr("Disks")
        BarText { visible: page.disks.length === 0; text: I18n.tr("Reading…"); color: Theme.dim }
        Repeater {
            model: page.disks
            delegate: ColumnLayout {
                id: disk
                required property var modelData
                required property int index
                // Like df: used over used + free (the size includes what is reserved for root)
                readonly property real frac: modelData.used + modelData.free > 0 ? modelData.used / (modelData.used + modelData.free) : 0
                Layout.fillWidth: true
                Layout.topMargin: index > 0 ? 6 : 0
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        BarText { text: page.diskName(disk.modelData.mount) + "  ·  " + disk.modelData.mount; font.bold: true }
                        BarText { text: disk.modelData.dev + " · " + disk.modelData.fs; color: Theme.dim; font.pixelSize: 11 }
                    }
                    BarText {
                        text: Math.round(disk.frac * 100) + "%"
                        font.family: Theme.displayFont
                        font.pixelSize: 24
                        font.weight: Font.Black
                        color: disk.frac >= 0.9 ? Theme.sel : Theme.fg
                    }
                }
                UsageBar { Layout.fillWidth: true; implicitHeight: 10; value: disk.frac; critical: 0.9 }
                BarText {
                    text: I18n.tr("%1 used of %2").arg(page.fmt(disk.modelData.used)).arg(page.fmt(disk.modelData.size))
                        + "  ·  " + I18n.tr("%1 free").arg(page.fmt(disk.modelData.free))
                    color: Theme.fgSoft
                    font.pixelSize: 12
                }
            }
        }
    }

    // --- Free up space ---
    SettingsGroup {
        label: I18n.tr("Free up space")
        SettingsRow {
            text: I18n.tr("pacman cache") + " · " + page.fmt(page.clean.pacman ?? 0)
            description: I18n.tr("Keeps the latest version of each package (to go back) and deletes those of uninstalled ones")
            Button {
                text: I18n.tr("Clean"); enabled: (page.clean.pacman ?? 0) > 0
                busy: page.running === "pacman"
                onClicked: page.run("pacman", I18n.tr("pacman cache"), "sudo paccache -rk1 && sudo paccache -ruk0")
            }
        }
        SettingsRow {
            text: I18n.tr("AUR cache (yay)") + " · " + page.fmt(page.clean.yay ?? 0)
            description: I18n.tr("What was downloaded and built when installing from the AUR (~/.cache/yay). Emptied without asking")
            Button { text: I18n.tr("Clean"); enabled: (page.clean.yay ?? 0) > 0; busy: yayProc.running; onClicked: yayProc.running = true }
        }
        SettingsRow {
            text: I18n.tr("Trash") + " · " + page.fmt(page.clean.papelera ?? 0)
            description: page.trashConfirm ? I18n.tr("It is deleted forever. Sure?") : I18n.tr("What you deleted from Nautilus")
            Button {
                kind: page.trashConfirm ? "primary" : "secondary"
                text: page.trashConfirm ? I18n.tr("Empty forever") : I18n.tr("Empty")
                enabled: (page.clean.papelera ?? 0) > 0
                busy: trashProc.running
                onClicked: {
                    if (!page.trashConfirm) { page.trashConfirm = true; confirmReset.restart(); return }
                    page.trashConfirm = false
                    trashProc.running = true
                }
            }
            Timer { id: confirmReset; interval: 5000; onTriggered: page.trashConfirm = false }
        }
        SettingsRow {
            text: I18n.tr("System journal") + " · " + page.fmt(page.clean.registro ?? 0)
            description: I18n.tr("The systemd journal; it is left at 200 MB")
            Button {
                text: I18n.tr("Trim"); enabled: (page.clean.registro ?? 0) > 209715200
                busy: page.running === "registro"
                onClicked: page.run("registro", I18n.tr("Journal"), "sudo journalctl --vacuum-size=200M")
            }
        }
        SettingsRow {
            text: I18n.tr("Orphan packages") + " · " + page.fmt(page.clean.huerfanos ?? 0)
            description: (page.clean.huerfanosN ?? 0) > 0
                ? I18n.tr("%1 installed as a dependency that nothing needs anymore").arg(page.clean.huerfanosN)
                : I18n.tr("None: everything installed as a dependency is in use")
            Button {
                text: I18n.tr("Remove"); enabled: (page.clean.huerfanosN ?? 0) > 0
                busy: page.running === "huerfanos"
                onClicked: page.run("huerfanos", I18n.tr("Orphans"), "pacman -Qtd; echo; sudo pacman -Rns $(pacman -Qtdq)")
            }
        }
        SettingsRow {
            visible: (page.clean.flatpak ?? 0) > 0
            text: "Flatpak · " + page.fmt(page.clean.flatpak ?? 0)
            description: I18n.tr("Removes runtimes and extensions that no app uses anymore")
            Button { text: I18n.tr("Clean"); busy: page.running === "flatpak"; onClicked: page.run("flatpak", "Flatpak", "flatpak uninstall --unused -y") }
        }
    }

    // --- Apps ---
    SettingsGroup {
        label: I18n.tr("Apps that take the most space")
        BarText { visible: page.apps.length === 0; text: appsProc.running ? I18n.tr("Calculating…") : I18n.tr("No data"); color: Theme.dim }
        Repeater {
            model: page.apps
            delegate: BarRow {
                id: appRow
                required property var modelData
                label: modelData.name
                tag: modelData.flatpak ? "Flatpak" : modelData.aur ? "AUR" : ""
                bytes: modelData.bytes
                max: page.apps.length ? page.apps[0].bytes : 1
                Button {
                    kind: "ghost"; text: I18n.tr("Manage")
                    onClicked: { ShellState.settingsArg = { app: appRow.modelData.id, flatpak: appRow.modelData.flatpak }; ShellState.settingsPage = "apps-installed" }
                }
            }
        }
    }

    // --- Folders ---
    SettingsGroup {
        label: I18n.tr("Home folder")
        BarText { visible: page.folders.length === 0; text: foldersProc.running ? I18n.tr("Calculating… (it can take a while)") : I18n.tr("No data"); color: Theme.dim }
        Repeater {
            model: page.folders
            delegate: BarRow {
                id: folderRow
                required property var modelData
                label: modelData.name
                detail: modelData.path.replace(Quickshell.env("HOME"), "~")
                bytes: modelData.bytes
                max: page.folders.length ? page.folders[0].bytes : 1
                Button { kind: "ghost"; icon: "󰉋"; text: I18n.tr("Open"); onClicked: Quickshell.execDetached(["xdg-open", folderRow.modelData.path]) }
            }
        }
    }
}
