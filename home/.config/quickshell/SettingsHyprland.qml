// Settings → Hyprland: hyprland.lua and the modules it loads with require() (also the ones those
// load, like conf/programs.lua from conf/keybinds.lua), in load order, each with the
// first line of its comment and a button that opens it in nvim (the menu's floating terminal). The
// list is read when the page opens: a new require shows up by itself. The ones the shell generates
// (first comment «Generated…», or «Generado…» in older files) are marked so they are not edited by hand.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: "Hyprland"
    subtitle: I18n.tr("hyprland.lua and the modules it loads, in load order. They open in nvim")

    readonly property string dir: Quickshell.env("HOME") + "/.config/hypr"
    property var files: []          // [{ path, desc, generated, depth }]

    function edit(path, title) {
        Quickshell.execDetached(["alacritty", "--class", "menu-terminal", "--title", title,
                                 "--working-directory", page.dir, "-e", "nvim", path])
    }

    // One line per file: level|relative path|first comment (without the wiki URL)
    Process {
        running: true
        command: ["bash", "-c",
            "cd \"$1\" || exit; " +
            "desc() { sed -n '/^--/{s/^-- *//; s/ — https.*//; s/[.:]$//; p; q}' \"$1\" 2>/dev/null; }; " +
            "listar() { local m f; " +
            // require("x") and pcall(require, "x") (the optional ones, like the theme's conf/tema.lua)
            "  grep -v '^[[:space:]]*--' \"$1\" | grep -oE 'require(\\(|, )\"[^\"]+\"' | sed -E 's/.*\"(.*)\".*/\\1/' | " +
            "  while read -r m; do f=\"${m//.//}.lua\"; printf '%s|%s|%s\\n' \"$2\" \"$f\" \"$(desc \"$f\")\"; " +
            "    [[ -f $f ]] && listar \"$f\" $(($2 + 1)); done; }; " +
            "printf '0|hyprland.lua|%s\\n' \"$(desc hyprland.lua)\"; listar hyprland.lua 1",
            "hypr", page.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [], seen = new Set()
                for (const line of text.split("\n")) {
                    const p = line.split("|")
                    if (p.length < 3 || seen.has(p[1])) continue
                    seen.add(p[1])
                    const desc = p.slice(2).join("|")
                    out.push({ depth: parseInt(p[0]), path: p[1], desc: desc, generated: /^Genera(ted|do)\b/.test(desc) })
                }
                page.files = out
            }
        }
    }

    // Config errors (hyprctl configerrors): a .lua with an error leaves Hyprland half loaded
    property var errors: []
    Process {
        id: errProc
        running: true
        command: ["hyprctl", "configerrors"]
        stdout: StdioCollector { onStreamFinished: page.errors = text.split("\n").map(l => l.trim()).filter(l => l) }
    }
    Process { id: reloadProc; command: ["hyprctl", "reload"]; onExited: errLater.restart() }
    Timer { id: errLater; interval: 600; onTriggered: errProc.running = true }

    SettingsGroup {
        label: I18n.tr("Status")
        SettingsRow {
            text: page.errors.length ? I18n.trn(page.errors.length, "%1 error in the configuration", "%1 errors in the configuration")
                                     : I18n.tr("Configuration without errors")
            description: I18n.tr("Hyprland reloads by itself when a file is saved; «Reload» forces it and checks again")
            Button { icon: "󰑐"; text: I18n.tr("Reload"); busy: reloadProc.running; onClicked: reloadProc.running = true }
        }
        Repeater {
            model: page.errors
            delegate: BarText {
                required property string modelData
                text: "󰀦  " + modelData
                color: Theme.red; font.pixelSize: 12
                wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("Configuration files")
        BarText {
            visible: page.files.length === 0
            text: I18n.tr("Reading ~/.config/hypr/hyprland.lua…")
            color: Theme.dim
        }
        Repeater {
            model: page.files
            delegate: SettingsRow {
                id: row
                required property var modelData
                Layout.leftMargin: Math.max(0, modelData.depth - 1) * 18
                text: modelData.path
                description: modelData.desc
                Button {
                    icon: ""; text: row.modelData.generated ? I18n.tr("View") : I18n.tr("Edit")
                    onClicked: page.edit(page.dir + "/" + row.modelData.path, row.modelData.path.replace(/^conf\//, ""))
                }
            }
        }
    }

    SettingsGroup {
        SettingsRow {
            text: I18n.tr("The whole folder")
            description: I18n.tr("~/.config/hypr in nvim, with hypridle.conf, hyprlock.conf and xdph.conf. Hyprland reloads by itself on save")
            Button {
                icon: ""; text: I18n.tr("Open in nvim")
                onClicked: page.edit(page.dir, "hypr")
            }
        }
    }
}
