// Settings → Personalization → QuickShell → Menu: walker's system menu (SUPER+SPACE,
// ~/.local/bin/menu). Show or hide each section and option (hiding a section hides what
// is inside, in search too), reorder the sections of the main menu and add
// custom entries (text, icon and command, in the chosen section). Saved in
// settings.json (menuHidden, menuOrder, menuCustom) and the script reads it when it opens.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Menu")
    subtitle: I18n.tr("The system menu (Super + Space): what shows, in which order, and custom entries")
    readonly property var o: Config.options

    property var entries: []        // [{ route, icon, text, dest, key }] from «menu --entradas-todas»
    property var open: []           // expanded sections
    function load() { entriesProc.running = true }
    Component.onCompleted: load()

    Process {
        id: entriesProc
        command: [Quickshell.env("HOME") + "/.local/bin/menu", "--entradas-todas"]
        stdout: StdioCollector {
            onStreamFinished: page.entries = text.split("\n").filter(l => l.split("|").length === 4).map(l => {
                const p = l.split("|")
                return { route: p[0], icon: p[1], text: p[2], dest: p[3], key: p[0] ? p[0] + "/" + p[2] : p[2] }
            })
        }
    }

    // Sections of the main menu, in the saved order (missing ones, at the end)
    readonly property var sections: {
        const t = entries.filter(e => e.route === "")
        const ord = o.menuOrder ?? []
        const rank = e => { const i = ord.indexOf(e.text); return i < 0 ? 1000 + t.indexOf(e) : i }
        return t.slice().sort((a, b) => rank(a) - rank(b))
    }
    function childrenOf(route) { return entries.filter(e => e.route === route) }
    // The table's paths and texts are in English (they are also the keys of menuHidden and menuOrder)
    function routeView(r) { return r.split("/").map(p => I18n.tr(p)).join(" › ") }
    function hidden(key) { return (o.menuHidden ?? []).includes(key) }
    // A single assignment per change (settings.json is saved on each one)
    function toggle(key) {
        const h = (o.menuHidden ?? []).slice(), i = h.indexOf(key)
        if (i < 0) h.push(key); else h.splice(i, 1)
        o.menuHidden = h
    }
    function move(e, delta) {
        const list = sections.map(x => x.text), i = list.indexOf(e.text), j = i + delta
        if (j < 0 || j >= list.length) return
        list.splice(i, 1); list.splice(j, 0, e.text)
        o.menuOrder = list
    }
    function isOpen(k) { return open.includes(k) }
    function flip(k) { open = isOpen(k) ? open.filter(x => x !== k) : open.concat([k]) }

    // Row of an option: icon, text, (expand if it is a submenu), visible
    component EntryRow: RowLayout {
        id: er
        property var e
        property int depth: 0
        property bool parentHidden: false
        readonly property bool isMenu: e.dest.startsWith(">")
        readonly property bool off: page.hidden(e.key)
        Layout.fillWidth: true
        Layout.leftMargin: depth * 22
        spacing: 10
        opacity: parentHidden ? 0.4 : 1
        BarText { text: er.e.icon; font.pixelSize: 15; color: er.off ? Theme.dim : Theme.fgSoft; Layout.preferredWidth: 20 }
        BarText {
            text: I18n.tr(er.e.text)
            color: er.off ? Theme.dim : Theme.fg
            font.strikeout: er.off
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Tag { visible: er.e.dest.startsWith("propia:"); text: I18n.tr("Added") }
        IconButton {
            visible: er.isMenu
            icon: page.isOpen(er.e.key) ? "󰅀" : "󰅂"
            onClicked: page.flip(er.e.key)
        }
        Toggle { checked: !er.off; onToggled: page.toggle(er.e.key) }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        BarText {
            Layout.fillWidth: true
            text: I18n.tr("Changes show the next time you open the menu. What is hidden does not show in search either")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap
        }
        Button { icon: "󰍜"; text: I18n.tr("Open the menu"); onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/menu"]) }
    }

    // --- Sections ---
    SettingsGroup {
        label: I18n.tr("Sections of the main menu")
        BarText { visible: page.entries.length === 0; text: I18n.tr("Reading the menu…"); color: Theme.dim }
        Repeater {
            model: page.sections
            delegate: ColumnLayout {
                id: sec
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    // Up / down in the main menu
                    IconButton { icon: "󰁝"; size: 24; enabled: sec.index > 0; onClicked: page.move(sec.modelData, -1) }
                    IconButton { icon: "󰁅"; size: 24; enabled: sec.index < page.sections.length - 1; onClicked: page.move(sec.modelData, 1) }
                    EntryRow { e: sec.modelData; Layout.leftMargin: 6 }
                }
                // Options of the section (and those of its submenus)
                Repeater {
                    model: page.isOpen(sec.modelData.key) ? page.childrenOf(sec.modelData.key) : []
                    delegate: ColumnLayout {
                        id: sub
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        EntryRow { e: sub.modelData; depth: 2; parentHidden: page.hidden(sec.modelData.key) }
                        Repeater {
                            model: sub.modelData.dest.startsWith(">") && page.isOpen(sub.modelData.key) ? page.childrenOf(sub.modelData.key) : []
                            delegate: EntryRow {
                                required property var modelData
                                e: modelData; depth: 3
                                parentHidden: page.hidden(sec.modelData.key) || page.hidden(sub.modelData.key)
                            }
                        }
                    }
                }
            }
        }
        Button {
            kind: "ghost"; icon: "󰜉"; text: I18n.tr("Reset (everything visible and in the usual order)")
            visible: (page.o.menuHidden ?? []).length > 0 || (page.o.menuOrder ?? []).length > 0
            onClicked: { page.o.menuHidden = []; page.o.menuOrder = [] }
        }
    }

    // --- Custom entries ---
    SettingsGroup {
        label: I18n.tr("Custom entries")
        BarText {
            text: I18n.tr("A command with its name and icon, in the main menu or inside a section (it also shows in search)")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        Repeater {
            model: page.o.menuCustom ?? []
            delegate: RowLayout {
                id: cu
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 10
                BarText { text: cu.modelData.icono || "󰘳"; font.pixelSize: 15; Layout.preferredWidth: 20 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    BarText { text: cu.modelData.texto + "  ·  " + (cu.modelData.ruta ? page.routeView(cu.modelData.ruta) : I18n.tr("Main menu")); elide: Text.ElideRight; Layout.fillWidth: true }
                    BarText { text: cu.modelData.comando; color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                IconButton {
                    danger: true
                    onClicked: page.o.menuCustom = (page.o.menuCustom ?? []).filter((_, i) => i !== cu.index)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField { id: cIcon; Layout.preferredWidth: 56; placeholder: "󰘳" }
            WifiField { id: cText; Layout.preferredWidth: 180; placeholder: I18n.tr("Name") }
            WifiField { id: cCmd; Layout.fillWidth: true; placeholder: I18n.tr("Command (e.g. firefox --private-window)") }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            BarText { text: I18n.tr("In"); color: Theme.fgSoft }
            ChoiceChips {
                id: cRoute
                Layout.fillWidth: true
                property string route: ""
                value: route
                options: [{ v: "", label: I18n.tr("Main menu") }].concat(page.sections.filter(e => e.dest.startsWith(">")).map(e => ({ v: e.dest.slice(1), label: I18n.tr(e.text) })))
                onChosen: v => route = v
            }
            Button {
                kind: "primary"; icon: "󰐕"; text: I18n.tr("Add")
                enabled: cText.text.trim() !== "" && cCmd.text.trim() !== ""
                onClicked: {
                    page.o.menuCustom = (page.o.menuCustom ?? []).concat([{ ruta: cRoute.route, icono: cIcon.text.trim(), texto: cText.text.trim(), comando: cCmd.text.trim() }])
                    cIcon.text = ""; cText.text = ""; cCmd.text = ""
                }
            }
        }
    }

    // After changing the custom ones, the menu's entry list changes
    Connections {
        target: page.o
        function onMenuCustomChanged() { page.load() }
    }
}
