// Settings → Personalization → Themes: the desktop theme (shell, Alacritty, walker, GTK and Hyprland
// borders; applied by scripts/tema.sh). The installed ones (Nothing is included) with a
// preview, «Apply» and remove; tinted-theming's base16 catalog (downloaded once) with
// search and a light/dark filter: picking one lets you choose the accent among its colors and
// installs it (the 16 base16 colors are mapped to our layers: backgrounds, texts, accent and terminal).
// Below, the shapes (gaps and rounding; also in Hyprland), in settings.json.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Themes")
    subtitle: I18n.tr("Colors of the whole desktop: shell, terminal, launcher, GTK apps and window borders")
    readonly property var o: Config.options
    readonly property string script: Quickshell.shellPath("scripts/tema.sh")

    property var installed: []      // [{ path, t: theme }]
    property string current: ""
    property var catalog: []        // [{ id, name, author, variant, c: { "00": "#…", … } }]
    property string query: ""
    property string variant: "all"
    property int shown: 48
    property var picked: null       // scheme chosen from the catalog
    property string accentKey: "0D" // its accent color
    property string message: ""
    property string busy: ""       // id of the one being applied or installed

    function rows(text, tag) { return text.split("\n").filter(l => l.startsWith(tag + "|")).map(l => l.split("|")) }
    function load() { listProc.running = true }
    Component.onCompleted: { load(); catProc.running = true }

    // --- Colors: from base16 to our layers ---
    function hex(c) { c = c.replace("#", ""); return [0, 2, 4].map(i => parseInt(c.substr(i, 2), 16)) }
    function toHex(a) { return "#" + a.map(v => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, "0")).join("") }
    function mix(a, b, t) { const x = hex(a), y = hex(b); return toHex(x.map((v, i) => v + (y[i] - v) * t)) }
    function lum(c) {
        const l = hex(c).map(v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) })
        return 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
    }
    function contrast(a, b) { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05) }
    // The layers come from mixing the background (base00) with the text (base05): that way the order of base01/02
    // in each scheme does not matter and they all end up like Nothing (background, card, control, border…)
    function fromBase16(sc, key) {
        const b = k => sc.c[k], bg = b("00"), fg = b("05"), sel = b(key)
        // In light ones, the text greys closer to the text (otherwise they are hard to read)
        const light = sc.variant === "light"
        const selText = contrast(sel, bg) >= contrast(sel, fg) ? bg : fg
        return {
            id: "b16-" + sc.id + (key !== "0D" ? "-" + key.toLowerCase() : ""),
            name: sc.name + (key !== "0D" ? " · " + accentName(key) : ""),
            origin: "base16", author: sc.author, variant: sc.variant,
            colors: {
                bg: bg, bgAlt: mix(bg, fg, 0.03), surface: mix(bg, fg, 0.06), control: mix(bg, fg, 0.11),
                controlHi: mix(bg, fg, 0.16), border: mix(bg, fg, 0.14), fg: fg, fgSoft: mix(bg, fg, light ? 0.82 : 0.72),
                dim: mix(bg, fg, light ? 0.62 : 0.45), red: b("08"), sel: sel, selHi: mix(sel, fg, 0.18), selSoft: mix(bg, sel, 0.18),
                selText: selText, accent: sel, accentText: selText, dot: mix(bg, fg, 0.12)
            },
            terminal: {
                background: bg, foreground: fg, cursor: sel, cursorText: bg, viCursor: b("0E"),
                selection: mix(bg, sel, 0.35), selectionText: fg, searchMatch: mix(bg, sel, 0.22),
                normal: ["00", "08", "0B", "0A", "0D", "0E", "0C", "05"].map(b),
                bright: ["03", "08", "0B", "0A", "0D", "0E", "0C", "07"].map(b)
            }
        }
    }
    readonly property var accentKeys: ["08", "09", "0A", "0B", "0C", "0D", "0E", "0F"]
    function accentName(k) { return I18n.tr(({ "08": "red", "09": "orange", "0A": "yellow", "0B": "green", "0C": "cyan", "0D": "blue", "0E": "violet", "0F": "brown" })[k]) }

    // --- Processes ---
    Process {
        id: listProc
        command: [page.script, "lista"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    if (line.startsWith("tema|")) {
                        const i = line.indexOf("|", 5)
                        try { out.push({ path: line.slice(5, i), t: JSON.parse(line.slice(i + 1)) }) } catch (e) {}
                    } else if (line.startsWith("actual|")) page.current = line.slice(7)
                }
                page.installed = out
            }
        }
    }
    Process {
        id: catProc
        command: [page.script, "catalogo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keys = ["00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "0A", "0B", "0C", "0D", "0E", "0F"]
                page.catalog = page.rows(text, "esquema").map(r => {
                    const c = {}
                    keys.forEach((k, i) => c[k] = "#" + r[5 + i])
                    return { id: r[1], name: r[2], author: r[3], variant: r[4], c: c }
                }).sort((a, b) => a.name.localeCompare(b.name))
                const err = page.rows(text, "error")[0]
                if (err) page.message = I18n.tr(err[1])
            }
        }
    }
    Process {
        id: applyProc
        onExited: code => { page.busy = ""; if (code !== 0) page.message = I18n.tr("Could not apply the theme"); page.load() }
    }
    function apply(path, name) {
        busy = path; message = I18n.tr("«%1» applied to the whole desktop (open GTK apps pick it up when restarted)").arg(name)
        applyProc.command = [script, "aplicar", path]
        applyProc.running = true
    }
    // Save a theme from the catalog and, if asked, apply it («guardar» returns the path)
    Process {
        id: saveProc
        property bool andApply: false
        property string name: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (!path) { page.message = I18n.tr("Could not install"); page.busy = ""; return }
                page.picked = null
                if (saveProc.andApply) page.apply(path, saveProc.name)
                else { page.busy = ""; page.message = I18n.tr("«%1» installed").arg(saveProc.name); page.load() }
            }
        }
    }
    function install(sc, key, andApply) {
        const t = fromBase16(sc, key)
        busy = t.id
        saveProc.andApply = andApply; saveProc.name = t.name
        saveProc.command = ["sh", "-c", 'printf "%s" "$1" | "$2" guardar', "sh", JSON.stringify(t), script]
        saveProc.running = true
    }
    Process { id: removeProc; onExited: page.load() }

    readonly property var filtered: {
        const q = query.toLowerCase()
        return catalog.filter(s => (variant === "all" || s.variant === variant)
                                 && (!q || s.name.toLowerCase().includes(q) || s.id.includes(q)))
    }

    // --- Theme preview: background, card, texts, accent and the terminal colors ---
    component Preview: Rectangle {
        id: pv
        property var c: ({})             // tokens (colors)
        property var term: []            // 8 terminal colors
        implicitHeight: 86
        radius: 10
        color: c.bg ?? "#000"
        border.color: c.border ?? "#333"; border.width: 1
        clip: true
        Rectangle {
            x: 10; y: 10; width: parent.width - 20; height: 40; radius: 7
            color: pv.c.surface ?? "#111"
            Column {
                x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                Rectangle { width: 70; height: 6; radius: 3; color: pv.c.fg ?? "#fff" }
                Rectangle { width: 46; height: 5; radius: 3; color: pv.c.dim ?? "#777" }
            }
            Rectangle {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                width: 34; height: 16; radius: 8; color: pv.c.sel ?? "#f00"
            }
        }
        Row {
            x: 10; y: 60; spacing: 4
            Repeater {
                model: pv.term
                delegate: Rectangle { required property var modelData; width: 14; height: 14; radius: 7; color: modelData }
            }
        }
    }
    // Card of an installed theme or one from the catalog
    component Card: Rectangle {
        id: card
        property string name
        property var c: ({})
        property var term: []
        property bool selected: false
        property bool clickable: false
        signal clicked
        default property alias extra: foot.data
        width: 200
        implicitHeight: col.implicitHeight + 16
        radius: 12
        color: cardHover.hovered || selected ? Theme.control : "transparent"
        border.color: selected ? Theme.sel : cardHover.hovered ? Theme.border : "transparent"
        border.width: 1
        HoverHandler { id: cardHover; cursorShape: card.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: card.clickable; onTapped: card.clicked() }
        ColumnLayout {
            id: col
            x: 8; y: 8; width: parent.width - 16
            spacing: 6
            Preview { Layout.fillWidth: true; c: card.c; term: card.term }
            BarText { text: card.name; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            RowLayout { id: foot; Layout.fillWidth: true; spacing: 6 }
        }
    }

    BarText {
        visible: page.message !== ""
        text: page.message
        color: Theme.fgSoft; font.pixelSize: 12
        wrapMode: Text.Wrap; Layout.fillWidth: true
    }

    // --- Installed ---
    SettingsGroup {
        label: I18n.tr("Installed", "themes")
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: page.installed
                delegate: Card {
                    id: it
                    required property var modelData
                    readonly property bool inUse: modelData.t.id === page.current
                    name: modelData.t.name
                    c: modelData.t.colors
                    term: modelData.t.terminal?.normal?.slice(1, 7) ?? []
                    selected: inUse
                    Tag { text: it.modelData.t.origin === "integrado" ? I18n.tr("Included") : "Base16" }
                    Tag { visible: it.inUse; text: I18n.tr("In use") }
                    Item { Layout.fillWidth: true }
                    Button {
                        visible: !it.inUse
                        text: I18n.tr("Apply")
                        busy: page.busy === it.modelData.path
                        onClicked: page.apply(it.modelData.path, it.modelData.t.name)
                    }
                    IconButton {
                        visible: !it.inUse && it.modelData.t.origin !== "integrado"
                        danger: true
                        onClicked: { removeProc.command = [page.script, "quitar", it.modelData.t.id]; removeProc.running = true }
                    }
                }
            }
        }
    }

    // --- base16 catalog ---
    SettingsGroup {
        label: I18n.tr("base16 catalog") + (page.catalog.length ? " · " + I18n.tr("%1 schemes").arg(page.catalog.length) : "")
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField {
                Layout.fillWidth: true
                search: true
                placeholder: I18n.tr("Search (catppuccin, gruvbox, nord, tokyo night…)")
                onTextChanged: { page.query = text.trim(); page.shown = 48 }
            }
            ChoiceChips {
                value: page.variant
                options: [{ v: "all", label: I18n.tr("All", "packages") }, { v: "dark", label: I18n.tr("Dark") }, { v: "light", label: I18n.tr("Light") }]
                onChosen: v => { page.variant = v; page.shown = 48 }
            }
            IconButton {
                icon: "󰑐"
                busy: catProc.running
                onClicked: { catProc.command = [page.script, "catalogo", "--actualizar"]; catProc.running = true }
            }
        }
        BarText {
            visible: page.catalog.length === 0
            text: catProc.running ? I18n.tr("Downloading the tinted-theming catalog… (only the first time)") : I18n.tr("No catalog")
            color: Theme.dim
        }

        // The chosen one: its accent and buttons to install it
        Rectangle {
            id: pickBox
            visible: page.picked !== null
            Layout.fillWidth: true
            implicitHeight: pick.implicitHeight + 24
            radius: 12
            color: Theme.selSoft
            border.color: Theme.sel; border.width: 1
            readonly property var preview: page.picked ? page.fromBase16(page.picked, page.accentKey) : null
            RowLayout {
                id: pick
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 14
                Preview {
                    Layout.preferredWidth: 200
                    c: pickBox.preview?.colors ?? ({})
                    term: pickBox.preview?.terminal.normal.slice(1, 7) ?? []
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    BarText { text: page.picked?.name ?? ""; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    BarText { text: page.picked?.author ?? ""; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                    BarText { text: I18n.tr("Accent (buttons, selection, bar)"); color: Theme.fgSoft; font.pixelSize: 11 }
                    Row {
                        spacing: 6
                        Repeater {
                            model: page.accentKeys
                            delegate: Rectangle {
                                required property string modelData
                                width: 26; height: 26; radius: 13
                                color: page.picked ? page.picked.c[modelData] : "transparent"
                                border.color: page.accentKey === modelData ? Theme.fg : "transparent"
                                border.width: 2
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.accentKey = parent.modelData }
                            }
                        }
                    }
                    RowLayout {
                        spacing: 8
                        Button {
                            kind: "primary"; text: I18n.tr("Install and apply")
                            busy: page.busy !== ""
                            onClicked: page.install(page.picked, page.accentKey, true)
                        }
                        Button { text: I18n.tr("Install"); busy: page.busy !== ""; onClicked: page.install(page.picked, page.accentKey, false) }
                        Button { kind: "ghost"; text: I18n.tr("Close"); onClicked: page.picked = null }
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: page.filtered.slice(0, page.shown)
                delegate: Card {
                    id: sc
                    required property var modelData
                    name: modelData.name
                    c: page.fromBase16(modelData, "0D").colors
                    term: ["08", "0B", "0A", "0D", "0E", "0C"].map(k => sc.modelData.c[k])
                    selected: page.picked?.id === modelData.id
                    Tag { text: sc.modelData.variant === "light" ? I18n.tr("Light", "theme") : I18n.tr("Dark", "theme") }
                    clickable: true
                    onClicked: { page.picked = sc.modelData; page.accentKey = "0D" }
                }
            }
        }
        RowLayout {
            visible: page.filtered.length > 0
            Layout.fillWidth: true
            BarText {
                Layout.fillWidth: true
                text: I18n.tr("%1 of %2 · click one to choose its accent and install it").arg(Math.min(page.shown, page.filtered.length)).arg(page.filtered.length)
                color: Theme.dim; font.pixelSize: 11
            }
            Button { visible: page.shown < page.filtered.length; text: I18n.tr("Show more"); onClicked: page.shown += 48 }
        }
    }

    SettingsGroup {
        label: I18n.tr("Shapes")
        SettingsRow {
            text: I18n.tr("Gaps")
            description: I18n.tr("Space between windows, bar and the screen edge")
            SliderField { value: o.gap; from: 0; to: 24; suffix: " px"; onMoved: v => o.gap = Math.round(v) }
        }
        SettingsRow {
            text: I18n.tr("Window rounding")
            description: I18n.tr("Windows, bar and panels")
            SliderField { value: o.radius; from: 0; to: 24; suffix: " px"; onMoved: v => o.radius = Math.round(v) }
        }
        SettingsRow {
            text: I18n.tr("Screen corners")
            description: I18n.tr("Rounding of the monitor's corners")
            SliderField { value: o.screenRadius; from: 0; to: 40; suffix: " px"; onMoved: v => o.screenRadius = Math.round(v) }
        }
    }

    Button {
        kind: "ghost"; icon: "󰜉"; text: I18n.tr("Reset the shapes")
        onClicked: Config.reset(["gap", "radius", "screenRadius"])
    }
}
