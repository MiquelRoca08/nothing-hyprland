// Settings → Apps → Install: searches the repositories (pacman -Ss), the AUR
// (yay, by popularity) and Flathub at once, and each result is installed in the floating terminal (when
// done, Terminal.run notifies and the search is repeated to mark what is installed). Below, create a
// WebApp or a TUI (with ~/.local/bin/webapp and tui, like the system menu). Data from
// scripts/aplicaciones.sh.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Install apps")
    subtitle: I18n.tr("Repositories, AUR and Flathub; and WebApps and TUIs for the launcher")

    readonly property string script: Quickshell.shellPath("scripts/aplicaciones.sh")
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
    property string query: ""       // the last thing searched
    property string source: "all"
    property var results: ({ repos: [], aur: [], flatpak: [] })
    property string running: ""     // origin/name being installed
    property string made: ""        // notice after creating a WebApp or a TUI
    property string tuiStyle: "flotante"

    readonly property var sources: [
        { k: "repos", label: I18n.tr("Repositories"), proc: reposProc },
        { k: "aur", label: "AUR", proc: aurProc },
        { k: "flatpak", label: "Flathub", proc: flatpakProc },
    ]
    readonly property bool searching: reposProc.running || aurProc.running || flatpakProc.running

    // Searches all three at once; whatever is still running from the previous search is cut
    function search(text) {
        query = text.trim()
        for (const s of sources) {
            s.proc.running = false
            if (!query) continue
            s.proc.command = [script, "buscar-" + s.k, query]
            s.proc.running = true
        }
        if (!query) results = { repos: [], aur: [], flatpak: [] }
    }
    // While typing: after a 0.4 s pause and with 2 letters or more (Enter searches right away)
    Timer { id: typing; interval: 250; onTriggered: page.search(field.text.trim().length >= 2 ? field.text : "") }
    function setResults(k, text) {
        const r = Object.assign({}, results)
        r[k] = text.split("\n").filter(l => l.startsWith("res|")).map(l => {
            const p = l.split("|")
            // flatpak: res|flatpak|id|version|installed|description|name
            return { id: p[2], name: k === "flatpak" ? (p[6] || p[2]) : p[2], version: p[3], installed: p[4] === "1", desc: p[5] }
        })
        results = r
    }
    function install(k, it) {
        running = k + "/" + it.id
        const cmd = k === "repos" ? "sudo pacman -S " + it.id
                  : k === "aur" ? "yay -S " + it.id
                  : "flatpak install -y flathub " + it.id
        Terminal.run(I18n.tr("Install %1").arg(it.name), cmd)
    }
    Connections {
        target: ShellState
        function onSettingsChanged() { page.running = ""; if (page.query) page.search(page.query) }
    }

    Process { id: reposProc; stdout: StdioCollector { onStreamFinished: page.setResults("repos", text) } }
    Process { id: aurProc; stdout: StdioCollector { onStreamFinished: page.setResults("aur", text) } }
    Process { id: flatpakProc; stdout: StdioCollector { onStreamFinished: page.setResults("flatpak", text) } }

    // --- Search ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        WifiField {
            id: field
            search: true
            Layout.fillWidth: true
            placeholder: I18n.tr("What do you want to install? Search the repositories, AUR and Flathub")
            onTextChanged: typing.restart()
            onAccepted: { typing.stop(); page.search(text) }
            onCleared: { typing.stop(); page.search("") }
            Component.onCompleted: focusInput()
        }
        BarText { visible: page.searching; text: I18n.tr("Searching…"); color: Theme.dim; font.pixelSize: 12 }
    }
    ChoiceChips {
        visible: page.query !== ""
        Layout.fillWidth: true
        value: page.source
        options: [{ v: "all", label: I18n.tr("All") }].concat(page.sources.map(s => (
            { v: s.k, label: s.label + " · " + (s.proc.running ? "…" : page.results[s.k].length) })))
        onChosen: v => page.source = v
    }

    Repeater {
        model: page.query ? page.sources.filter(s => page.source === "all" || page.source === s.k) : []
        delegate: SettingsGroup {
            id: group
            required property var modelData
            readonly property var items: page.results[modelData.k]
            label: modelData.label
            BarText {
                visible: group.items.length === 0
                text: group.modelData.proc.running ? I18n.tr("Searching…") : I18n.tr("Nothing with «%1»").arg(page.query)
                color: Theme.dim
            }
            BarText {
                visible: group.modelData.k === "aur" && group.items.length > 0
                text: I18n.tr("AUR packages are maintained by the community: yay lets you review the PKGBUILD before building")
                color: Theme.dim
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Repeater {
                model: group.items
                delegate: RowLayout {
                    id: res
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 12
                    AppIcon { icon: res.modelData.id; implicitWidth: 24; implicitHeight: 24 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Row {
                            Layout.fillWidth: true
                            spacing: 8
                            BarText {
                                text: res.modelData.name
                                width: Math.min(implicitWidth, parent.width - ver.width - 8)
                                elide: Text.ElideRight
                                anchors.baseline: ver.baseline
                            }
                            BarText { id: ver; text: res.modelData.version; color: Theme.dim; font.pixelSize: 11 }
                        }
                        BarText {
                            text: (group.modelData.k === "flatpak" ? res.modelData.id + " · " : "") + res.modelData.desc
                            color: Theme.dim
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Rectangle {
                        visible: res.modelData.installed
                        Layout.preferredWidth: 110
                        implicitHeight: 32; radius: Theme.controlRadius
                        color: Theme.selSoft
                        BarText { anchors.centerIn: parent; text: "󰄬  " + I18n.tr("Installed", "package"); font.pixelSize: 12; color: Theme.sel }
                    }
                    Button {
                        visible: !res.modelData.installed
                        Layout.preferredWidth: 110
                        icon: "󰇚"; text: I18n.tr("Install")
                        busy: page.running === group.modelData.k + "/" + res.modelData.id
                        onClicked: page.install(group.modelData.k, res.modelData)
                    }
                }
            }
        }
    }

    BarText {
        visible: page.made !== ""
        text: "󰄬  " + page.made
        color: Theme.fgSoft
        font.pixelSize: 12
    }

    // --- WebApp ---
    SettingsGroup {
        label: I18n.tr("Create a WebApp")
        BarText {
            text: I18n.tr("A website in its own window, with an icon in the launcher (it opens with Chromium, or your browser if it is of that family)")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField { id: waName; Layout.preferredWidth: 180; placeholder: I18n.tr("Name") }
            WifiField { id: waUrl; Layout.fillWidth: true; placeholder: I18n.tr("Website (e.g. web.whatsapp.com)") }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField { id: waIcon; Layout.fillWidth: true; placeholder: I18n.tr("Icon: URL of a PNG (optional; otherwise, the website's)") }
            Button {
                kind: "primary"; text: I18n.tr("Create")
                enabled: waName.text.trim() !== "" && waUrl.text.trim() !== ""
                busy: waProc.running
                onClicked: {
                    waProc.command = [page.bin + "webapp", "crear", waName.text.trim(), waUrl.text.trim()].concat(waIcon.text.trim() ? [waIcon.text.trim()] : [])
                    waProc.running = true
                }
            }
        }
    }
    Process {
        id: waProc
        onExited: code => {
            if (code === 0) { page.made = I18n.tr("WebApp «%1» created: it is in the launcher").arg(waName.text.trim()); waName.text = ""; waUrl.text = ""; waIcon.text = "" }
            else page.made = I18n.tr("Could not create the WebApp")
        }
    }

    // --- TUI ---
    SettingsGroup {
        label: I18n.tr("Create a TUI")
        BarText {
            text: I18n.tr("A terminal program (btop, lazygit…) with its icon in the launcher; it opens in Alacritty")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField { id: tuiName; Layout.preferredWidth: 180; placeholder: I18n.tr("Name") }
            WifiField { id: tuiCmd; Layout.fillWidth: true; placeholder: I18n.tr("Command (e.g. lazygit)") }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ChoiceChips {
                value: page.tuiStyle
                options: [{ v: "flotante", label: I18n.tr("Floating") }, { v: "mosaico", label: I18n.tr("Tiled") }]
                onChosen: v => page.tuiStyle = v
            }
            WifiField { id: tuiIcon; Layout.fillWidth: true; placeholder: I18n.tr("Icon: URL or path (optional)") }
            Button {
                kind: "primary"; text: I18n.tr("Create")
                enabled: tuiName.text.trim() !== "" && tuiCmd.text.trim() !== ""
                busy: tuiProc.running
                onClicked: {
                    tuiProc.command = [page.bin + "tui", "crear", tuiName.text.trim(), tuiCmd.text.trim(), page.tuiStyle].concat(tuiIcon.text.trim() ? [tuiIcon.text.trim()] : [])
                    tuiProc.running = true
                }
            }
        }
    }
    Process {
        id: tuiProc
        onExited: code => {
            if (code === 0) { page.made = I18n.tr("TUI «%1» created: it is in the launcher").arg(tuiName.text.trim()); tuiName.text = ""; tuiCmd.text = ""; tuiIcon.text = "" }
            else page.made = I18n.tr("Could not create the TUI")
        }
    }
}
