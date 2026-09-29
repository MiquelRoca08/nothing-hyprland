// Settings → Personalization → Fonts: the installed families (each written in its own
// font, with a sample text that can be changed), their origin and package; make one
// the default (text: sans-serif + GTK interface; monospace: monospace + GTK's mono font);
// remove (the package in the terminal, or the files if they are the user's); search and install font
// packages from the repositories and the AUR; and install from a file (to ~/.local/share/fonts).
// Data from scripts/fonts.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Fonts")
    subtitle: I18n.tr("The installed ones and how they look; search, install or remove")

    readonly property string script: Quickshell.shellPath("scripts/fonts.sh")
    property var fonts: []          // [{ family, origin, pkg, files, bytes, dir, mono }]
    property string defSans: ""     // default fonts (fc-match sans-serif / monospace)
    property string defMono: ""
    property var results: []        // [{ origin, name, version, installed, desc }]
    property string query: ""       // filter for the installed ones
    property string searched: ""    // last package search
    property string sample: I18n.tr("The quick brown fox jumps over the lazy dog · 0123456789")
    property string uiFont: ""      // interface font (gsettings), without the size
    property string uiSize: "11"
    property string confirm: ""     // family asking for confirmation to remove
    property string running: ""     // family or package in progress
    property string message: ""
    readonly property int limit: 120

    readonly property var origins: ({ repos: "Repos", aur: "AUR", user: I18n.tr("Yours"), other: I18n.tr("System") })
    function load() { listProc.running = true; uiProc.running = true }
    Component.onCompleted: load()
    Connections {
        target: ShellState
        function onSettingsChanged() { page.running = ""; page.load(); if (page.searched) page.search(page.searched) }
    }
    function fmt(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB" }
    function rows(text, tag) { return text.split("\n").filter(l => l.startsWith(tag + "|")).map(l => l.split("|")) }

    readonly property var list: {
        const q = query.toLowerCase()
        return fonts.filter(f => !q || f.family.toLowerCase().includes(q) || f.pkg.toLowerCase().includes(q))
    }

    Process {
        id: listProc
        command: [page.script, "installed"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.fonts = page.rows(text, "font").map(r => (
                    { family: r[1], origin: r[2], pkg: r[3], files: +r[4], bytes: +r[5], dir: r[6], mono: r[7] === "1" }))
                    .sort((a, b) => a.family.localeCompare(b.family))
                page.setDefaults(text)
            }
        }
    }
    Process {
        id: uiProc
        command: ["gsettings", "get", "org.gnome.desktop.interface", "font-name"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().replace(/^'|'$/g, "").match(/^(.*?)\s+(\d+(?:\.\d+)?)$/)
                if (m) { page.uiFont = m[1]; page.uiSize = m[2] }
            }
        }
    }
    function setDefaults(text) {
        const d = rows(text, "default")
        if (d.length) { defSans = d[0][1]; defMono = d[0][2] }
    }
    Process {
        id: setDefault
        stdout: StdioCollector { onStreamFinished: page.setDefaults(text) }
        onExited: uiProc.running = true
    }
    Process { id: removeProc; onExited: { page.running = ""; page.load() } }
    Process {
        id: fileProc
        command: [page.script, "install-file"]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = page.rows(text, "installed")
                if (r.length) { page.message = I18n.tr("%1 file(s) installed in ~/.local/share/fonts").arg(r[0][1]); page.load() }
            }
        }
    }
    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: page.results = page.rows(text, "res").map(r => (
                { origin: r[1], name: r[2], version: r[3], installed: r[4] === "1", desc: r.slice(5).join("|") }))
        }
    }
    function search(text) {
        searched = text.trim()
        searchProc.running = false
        if (searched.length < 2) { results = []; return }
        searchProc.command = [script, "search", searched]
        searchProc.running = true
    }
    Timer { id: typing; interval: 250; onTriggered: page.search(pkgField.text) }

    function remove(f) {
        confirm = ""
        running = f.family
        if (f.origin === "user") { removeProc.command = [script, "remove-user", f.family]; removeProc.running = true }
        else Terminal.run(I18n.tr("Remove %1").arg(f.pkg), "sudo pacman -Rns " + f.pkg)
    }
    // System-wide default: text (sans-serif + GTK interface) or monospace
    function makeDefault(f) {
        setDefault.command = [script, "set-default", f.family, f.mono ? "1" : "0", uiSize]
        setDefault.running = true
        message = (f.mono ? I18n.tr("«%1» is now the default monospace font (open apps pick it up when restarted)") : I18n.tr("«%1» is now the default text font (open apps pick it up when restarted)")).arg(f.family)
    }

    BarText {
        visible: page.message !== ""
        text: "󰄬  " + page.message
        color: Theme.fgSoft
        font.pixelSize: 12
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }

    // --- Interface ---
    SettingsGroup {
        label: I18n.tr("Interface")
        SettingsRow {
            text: I18n.tr("Text: %1").arg(page.defSans || "…")
            description: I18n.tr("The one apps use by default (sans-serif) and the GTK interface") + (page.uiFont ? " (" + page.uiFont + " · " + page.uiSize + " pt)" : "")
            BarText { text: "Aa"; font.family: page.defSans || Theme.font; font.pixelSize: 22 }
        }
        SettingsRow {
            text: I18n.tr("Monospace: %1").arg(page.defMono || "…")
            description: I18n.tr("Terminals, code and whatever asks for monospace. Changed with «Make default» on a font below")
            BarText { text: "Aa"; font.family: page.defMono || Theme.font; font.pixelSize: 22 }
        }
        SettingsRow {
            text: I18n.tr("Sample text")
            WifiField {
                Layout.preferredWidth: 320
                text: page.sample
                onTextChanged: if (text) page.sample = text
            }
        }
    }

    // --- Installed ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        WifiField {
            Layout.fillWidth: true
            search: true
            placeholder: I18n.tr("Search the installed ones")
            onTextChanged: page.query = text
        }
        Button { icon: "󰈔"; text: I18n.tr("Install from file"); busy: fileProc.running; onClicked: fileProc.running = true }
    }

    SettingsGroup {
        label: I18n.trn(page.list.length, "%1 family installed", "%1 families installed")
        BarText { visible: page.list.length === 0; text: listProc.running ? I18n.tr("Loading…") : I18n.tr("No matches"); color: Theme.dim }
        Repeater {
            model: page.list.slice(0, page.limit)
            delegate: ColumnLayout {
                id: fam
                required property var modelData
                readonly property bool asking: page.confirm === modelData.family
                readonly property bool isDefault: modelData.family === (modelData.mono ? page.defMono : page.defSans)
                Layout.fillWidth: true
                spacing: 4
                // 1: name and buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    BarText { text: fam.modelData.family; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Button {
                        visible: !fam.asking
                        icon: fam.isDefault ? "󰄬" : ""
                        text: fam.isDefault ? I18n.tr("Default") : I18n.tr("Make default")
                        kind: fam.isDefault ? "ghost" : "secondary"
                        enabled: !fam.isDefault
                        busy: setDefault.running
                        onClicked: page.makeDefault(fam.modelData)
                    }
                    Button { visible: fam.asking; kind: "ghost"; text: I18n.tr("Cancel"); onClicked: page.confirm = "" }
                    Button { visible: fam.asking; kind: "primary"; text: I18n.tr("Remove"); onClicked: page.remove(fam.modelData) }
                    IconButton {
                        visible: !fam.asking
                        danger: true
                        enabled: fam.modelData.origin === "user" || fam.modelData.pkg !== ""
                        busy: page.running === fam.modelData.family
                        onClicked: page.confirm = fam.modelData.family
                    }
                }
                // 2: tags and information (they wrap if they do not fit)
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Tag { text: page.origins[fam.modelData.origin] ?? "" }
                    Tag { text: fam.modelData.mono ? I18n.tr("Monospace") : I18n.tr("Proportional") }
                    Tag { visible: fam.isDefault; text: I18n.tr("By default") }
                    BarText {
                        height: 18
                        text: (fam.modelData.pkg ? fam.modelData.pkg + " · " : "") + fam.modelData.files
                            + " " + (fam.modelData.files === 1 ? I18n.tr("file") : I18n.tr("files")) + " · " + page.fmt(fam.modelData.bytes)
                        color: Theme.dim; font.pixelSize: 11
                    }
                }
                // 3: sample in the font itself
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    text: page.sample
                    font.family: fam.modelData.family
                    font.pixelSize: 18
                    color: Theme.fgSoft
                    elide: Text.ElideRight
                }
                BarText {
                    visible: fam.asking
                    text: fam.modelData.origin === "user" ? I18n.tr("Its files are deleted from your home folder")
                        : I18n.tr("The package %1 is uninstalled (with all its families)").arg(fam.modelData.pkg)
                    color: Theme.fg; font.pixelSize: 11
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 1; color: Theme.control }
            }
        }
        BarText {
            visible: page.list.length > page.limit
            text: I18n.tr("Showing %1 of %2: search to narrow it down").arg(page.limit).arg(page.list.length)
            color: Theme.dim; font.pixelSize: 11
        }
    }

    // --- Search packages ---
    SettingsGroup {
        label: I18n.tr("Install more")
        WifiField {
            id: pkgField
            Layout.fillWidth: true
            search: true
            placeholder: I18n.tr("Search font packages in the repositories and the AUR (e.g. «inter», «noto», «nerd»)")
            onTextChanged: typing.restart()
            onAccepted: { typing.stop(); page.search(text) }
            onCleared: { typing.stop(); page.search("") }
        }
        BarText {
            visible: page.searched.length >= 2 && page.results.length === 0
            text: searchProc.running ? I18n.tr("Searching…") : I18n.tr("No font package with «%1»").arg(page.searched)
            color: Theme.dim
        }
        Repeater {
            model: page.results
            delegate: RowLayout {
                id: res
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Row {
                        Layout.fillWidth: true
                        spacing: 8
                        BarText { text: res.modelData.name; width: Math.min(implicitWidth, parent.width - 120); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                        Tag { text: res.modelData.origin === "aur" ? "AUR" : "Repos"; anchors.verticalCenter: parent.verticalCenter }
                    }
                    BarText { text: res.modelData.desc; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Rectangle {
                    visible: res.modelData.installed
                    Layout.preferredWidth: 110; implicitHeight: 32; radius: Theme.controlRadius
                    color: Theme.selSoft
                    BarText { anchors.centerIn: parent; text: "󰄬  " + I18n.tr("Installed", "package"); font.pixelSize: 12; color: Theme.sel }
                }
                Button {
                    visible: !res.modelData.installed
                    Layout.preferredWidth: 110
                    icon: "󰇚"; text: I18n.tr("Install")
                    busy: page.running === res.modelData.name
                    onClicked: {
                        page.running = res.modelData.name
                        Terminal.run(I18n.tr("Install %1").arg(res.modelData.name),
                                     (res.modelData.origin === "aur" ? "yay -S " : "sudo pacman -S ") + res.modelData.name + " && fc-cache -f")
                    }
                }
            }
        }
    }
}
