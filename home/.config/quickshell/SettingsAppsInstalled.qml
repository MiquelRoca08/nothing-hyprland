// Settings → Apps → Installed: the launcher's apps with their origin (repositories,
// AUR, Flatpak, WebApp, TUI or manual), size and «Uninstall» (with confirmation: pacman and Flatpak
// in the floating terminal; WebApps and TUIs with their scripts). «All packages»: the installed ones
// (dependencies too, with a filter). Coming from Storage («Manage»), ShellState.settingsArg
// brings the app: it is searched and highlighted. Data from scripts/aplicaciones.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Installed apps")
    subtitle: I18n.tr("The launcher's, or every package (dependencies too)")

    readonly property string script: Quickshell.shellPath("scripts/aplicaciones.sh")
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property var apps: []           // [{ name, icon, origin, id, bytes }]
    property var packages: []       // [{ name, icon, origin, id, bytes, explicit, desc }]
    property string view: "apps"
    property string source: "all"
    property string sort: "name"
    property string query: ""
    property string highlight: ""   // id of the app coming from Storage
    property string confirm: ""     // id asking for confirmation to uninstall
    property string running: ""     // id being uninstalled
    readonly property int limit: 150

    function load() { appsProc.running = true; pkgsProc.running = true }
    Component.onCompleted: {
        const arg = ShellState.settingsArg
        // Flatpak: in Apps; a package can be a dependency with no icon: in Packages
        if (arg && arg.app) { highlight = arg.app; view = arg.flatpak ? "apps" : "packages"; search.text = arg.app }
        ShellState.settingsArg = null
        load()
    }
    Connections {
        target: ShellState
        function onSettingsChanged() { page.running = ""; page.load() }
    }

    readonly property var origins: ({ repos: "Repos", aur: "AUR", flatpak: "Flatpak", webapp: "WebApp", tui: "TUI", otro: I18n.tr("Manual") })
    function fmt(b) {
        if (!b) return ""
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        if (b >= 1048576) return Math.round(b / 1048576) + " MB"
        return Math.max(1, Math.round(b / 1024)) + " KB"
    }
    function rows(text, tag) { return text.split("\n").filter(l => l.startsWith(tag + "|")).map(l => l.split("|")) }

    readonly property var list: {
        const q = query.toLowerCase()
        const base = view === "apps" ? apps : packages
        return base.filter(a => (source === "all" || a.origin === source
                                 || (source === "explicit" && a.explicit) || (source === "dep" && a.explicit === false))
                             && (!q || a.name.toLowerCase().includes(q) || a.id.toLowerCase().includes(q)))
                   .sort((a, b) => sort === "size" ? b.bytes - a.bytes : a.name.localeCompare(b.name))
    }

    Process {
        id: appsProc
        command: [page.script, "instaladas"]
        stdout: StdioCollector {
            onStreamFinished: page.apps = page.rows(text, "app").map(r => ({ name: r[1], icon: r[2], origin: r[3], id: r[4], bytes: +r[5] }))
        }
    }
    Process {
        id: pkgsProc
        command: [page.script, "paquetes"]
        stdout: StdioCollector {
            onStreamFinished: page.packages = page.rows(text, "paquete").map(r => (
                { name: r[1], icon: "package-x-generic", origin: r[3] === "1" ? "aur" : "repos", id: r[1], bytes: +r[2],
                  explicit: r[4] === "1", desc: r.slice(5).join("|") }))
        }
    }
    // WebApps and TUIs: their scripts remove them without asking (the confirmation is the one here)
    Process { id: removeProc; onExited: { page.running = ""; page.load() } }

    function uninstall(a) {
        confirm = ""
        running = a.id
        if (a.origin === "webapp" || a.origin === "tui") {
            removeProc.command = [bin + (a.origin === "webapp" ? "webapp" : "tui"), "quitar", a.id]
            removeProc.running = true
        } else if (a.origin === "flatpak") Terminal.run(I18n.tr("Uninstall %1").arg(a.name), "flatpak uninstall -y " + a.id)
        else Terminal.run(I18n.tr("Uninstall %1").arg(a.name), "sudo pacman -Rns " + a.id)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        WifiField {
            id: search
            search: true
            Layout.fillWidth: true
            placeholder: I18n.tr("Search by name or package")
            onTextChanged: page.query = text
        }
        Button { icon: "󰑐"; text: I18n.tr("Refresh"); busy: appsProc.running || pkgsProc.running; onClicked: page.load() }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ChoiceChips {
            value: page.view
            options: [{ v: "apps", label: I18n.tr("Apps") }, { v: "packages", label: I18n.tr("All packages") }]
            onChosen: v => { page.view = v; page.source = "all" }
        }
        Item { Layout.fillWidth: true }
        ChoiceChips {
            value: page.sort
            options: [{ v: "name", icon: "󰈚", label: I18n.tr("Name") }, { v: "size", icon: "󰋊", label: I18n.tr("Size") }]
            onChosen: v => page.sort = v
        }
    }
    ChoiceChips {
        Layout.fillWidth: true
        value: page.source
        options: page.view === "apps"
            ? [{ v: "all", label: I18n.tr("All", "apps") }, { v: "repos", label: "Repos" }, { v: "aur", label: "AUR" }, { v: "flatpak", label: "Flatpak" },
               { v: "webapp", label: "WebApps" }, { v: "tui", label: "TUIs" }, { v: "otro", label: I18n.tr("Manual") }]
            : [{ v: "all", label: I18n.tr("All", "packages") }, { v: "explicit", label: I18n.tr("Explicitly installed") }, { v: "dep", label: I18n.tr("Dependencies") },
               { v: "repos", label: "Repos" }, { v: "aur", label: "AUR" }]
        onChosen: v => page.source = v
    }

    SettingsGroup {
        label: (page.view === "apps" ? I18n.trn(page.list.length, "%1 app", "%1 apps") : I18n.trn(page.list.length, "%1 package", "%1 packages"))
        BarText {
            visible: page.list.length === 0
            text: appsProc.running || pkgsProc.running ? I18n.tr("Loading…") : I18n.tr("No matches")
            color: Theme.dim
        }
        Repeater {
            model: page.list.slice(0, page.limit)
            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool hl: page.highlight !== "" && modelData.id === page.highlight
                readonly property bool asking: page.confirm === modelData.id
                Layout.fillWidth: true
                implicitHeight: rowLay.implicitHeight + 12
                radius: 10
                color: hl ? Theme.selSoft : rowHover.hovered ? Theme.control : "transparent"
                border.color: hl ? Theme.sel : "transparent"
                border.width: 1
                HoverHandler { id: rowHover }
                RowLayout {
                    id: rowLay
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                    spacing: 12
                    AppIcon { icon: item.modelData.icon }
                    // Name and tag in a Row (not RowLayout: a nested one stretches and centres them)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Row {
                            Layout.fillWidth: true
                            spacing: 8
                            BarText {
                                id: appName
                                text: item.modelData.name
                                width: Math.min(implicitWidth, parent.width - tag.width - 8)
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Tag { id: tag; text: page.origins[item.modelData.origin] ?? ""; anchors.verticalCenter: parent.verticalCenter }
                        }
                        BarText {
                            text: item.asking ? I18n.tr("It is uninstalled together with what only it needed. Sure?")
                                : item.modelData.desc || (item.modelData.id !== item.modelData.name ? item.modelData.id : "")
                            visible: text !== ""
                            color: item.asking ? Theme.fg : Theme.dim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    BarText {
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignRight
                        text: page.fmt(item.modelData.bytes)
                        color: Theme.fgSoft
                    }
                    Button {
                        visible: item.asking
                        kind: "ghost"; text: I18n.tr("Cancel")
                        onClicked: page.confirm = ""
                    }
                    Button { visible: item.asking; kind: "primary"; text: I18n.tr("Uninstall"); onClicked: page.uninstall(item.modelData) }
                    // Manual ones (a loose .desktop, e.g. from Steam) are not uninstalled from here
                    IconButton {
                        visible: !item.asking
                        danger: true
                        enabled: item.modelData.origin !== "otro"
                        busy: page.running === item.modelData.id
                        onClicked: page.confirm = item.modelData.id
                    }
                }
            }
        }
        BarText {
            visible: page.list.length > page.limit
            text: I18n.tr("Showing %1 of %2: search to narrow it down").arg(page.limit).arg(page.list.length)
            color: Theme.dim
            font.pixelSize: 11
        }
    }
}
