// Settings → System → Keybinds: the keybinds in ~/.config/hypr/conf/keybinds.lua (the
// source of truth, read as is), grouped by their «-- ## …» headings, with search. «Change»
// captures a new combination and rewrites the first argument of that hl.bind (Hyprland reloads
// by itself on save). While capturing, Hyprland is in the empty «capture» submap so the
// combination reaches this page instead of running its keybind (Escape or 10 s idle: cancelled). The ones
// generated in a loop (workspaces 1–10) are not changed here: they open in nvim at their line.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Keybinds")
    subtitle: I18n.tr("Those in conf/keybinds.lua. When one changes, Hyprland applies it right away")

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/conf/keybinds.lua"
    property var binds: []          // [{ line, section, parts, desc, expr, editable }]
    property var sections: []       // headings in order
    property string query: ""
    property int editing: -1        // line of the keybind being changed
    property bool capturing: false
    property var captured: null     // [parts] of the new combination
    property string message: ""

    // --- Read keybinds.lua ---
    FileView {
        id: file
        path: page.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.parse(text())
    }

    // Text of a Lua string expression: "a" .. var .. "b" (mainMod = SUPER; any other variable,
    // a loop's: shown as a range). null if it is not of that form.
    function luaText(expr) {
        let out = "", vars = false
        for (const tok of expr.split("..").map(t => t.trim())) {
            const m = tok.match(/^"((?:[^"\\]|\\.)*)"$/)
            if (m) out += m[1]
            else if (tok === "mainMod") out += "SUPER"
            else if (/^\w+$/.test(tok)) { out += tok === "key" ? "1…0" : "1–10"; vars = true }
            else return null
        }
        return { text: out, vars: vars }
    }
    function parse(text) {
        const lines = text.split("\n"), out = [], secs = []
        let section = "General", skip = false
        for (let i = 0; i < lines.length; i++) {
            const raw = lines[i], t = raw.trim()
            if (/^hl\.define_submap\("capture"/.test(t)) { skip = true; continue }
            if (skip) { if (/^end\)/.test(t)) skip = false; continue }
            const sm = t.match(/^-- ## (.+)/)
            if (sm) { section = sm[1]; continue }
            if (t.startsWith("--")) continue
            const b = raw.indexOf("hl.bind(")
            if (b < 0) continue
            // First argument: up to the first comma outside quotes
            let j = b + 8, q = false
            for (; j < raw.length; j++) {
                if (raw[j] === '"' && raw[j - 1] !== "\\") q = !q
                else if (raw[j] === "," && !q) break
            }
            const key = luaText(raw.slice(b + 8, j).trim())
            if (!key) continue
            // Description: d("…") or description = "…", on this line or the following ones (function)
            let desc = null
            for (let k = i; k < Math.min(lines.length, i + 10); k++) {
                if (k > i && lines[k].includes("hl.bind(")) break
                const dm = lines[k].match(/(?:\bd\(|description\s*=\s*)("(?:[^"\\]|\\.)*"(?:\s*\.\.\s*\w+)?)/)
                if (dm) { desc = luaText(dm[1]); break }
            }
            if (!secs.includes(section)) secs.push(section)
            out.push({ line: i, section: section, parts: key.text.split("+").map(p => p.trim()).filter(p => p),
                       desc: desc ? desc.text : I18n.tr("(no description)"), editable: !key.vars, start: b + 8, end: j })
        }
        binds = out
        sections = secs
    }

    // --- Key names and comparison ---
    readonly property var pretty: ({
        "SUPER": "Super", "CTRL": "Ctrl", "ALT": "Alt", "SHIFT": "Shift",
        "mouse:272": I18n.tr("Left click"), "mouse:273": I18n.tr("Right click"), "mouse_down": I18n.tr("Wheel ↓"), "mouse_up": I18n.tr("Wheel ↑"),
        "left": "←", "right": "→", "up": "↑", "down": "↓", "Return": "Enter", "SPACE": I18n.tr("Space"),
        "TAB": "Tab", "Print": I18n.tr("PrtSc"), "Escape": "Esc", "BackSpace": I18n.tr("Backspace"),
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": I18n.tr("Mute"),
        "XF86AudioMicMute": I18n.tr("Mic"), "XF86MonBrightnessUp": I18n.tr("Brightness +"), "XF86MonBrightnessDown": I18n.tr("Brightness −"),
        "XF86AudioNext": "⏭", "XF86AudioPrev": "⏮", "XF86AudioPlay": "⏯", "XF86AudioPause": "⏸",
    })
    function prettyKey(p) { return pretty[p] ?? pretty[p.toUpperCase()] ?? p }
    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]
    // Normalized combination for comparing: sorted modifiers + lowercase key
    function norm(parts) {
        const mods = parts.slice(0, -1).map(p => p.toUpperCase()).sort((a, b) => modOrder.indexOf(a) - modOrder.indexOf(b))
        return mods.concat([parts[parts.length - 1].toLowerCase()]).join("+")
    }
    // All combinations in use (loops expanded to 1…0), to warn about clashes
    function conflict(parts) {
        const n = norm(parts)
        for (const b of binds) {
            if (b.line === editing) continue
            const last = b.parts[b.parts.length - 1]
            const keys = last === "1…0" ? ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] : [last]
            for (const k of keys) if (norm(b.parts.slice(0, -1).concat([k])) === n) return descView(b.desc)
        }
        return ""
    }
    // Normal key (letter, number, space…) with no modifier: it could no longer be typed
    function bare(parts) {
        return parts.length === 1 && /^([A-Za-z0-9]|SPACE|Return|TAB|BackSpace|Delete|left|right|up|down)$/.test(parts[0])
    }

    // Descriptions and headings of keybinds.lua are in English: shown in the interface language.
    // Those with a trailing number or range (loops: «Go to workspace 1–10») translate the rest
    function descView(s) {
        const m = s.match(/^(.*) (\S*\d\S*)$/)
        return m && I18n.tr(s) === s ? I18n.tr(m[1]) + " " + m[2] : I18n.tr(s)
    }

    function matches(b) {
        return !query || descView(b.desc).toLowerCase().includes(query)
            || b.parts.map(p => prettyKey(p)).join(" + ").toLowerCase().includes(query)
            || b.parts.join(" + ").toLowerCase().includes(query)
    }

    // --- Capture ---
    function startCapture(line) {
        editing = line; captured = null; message = ""
        capturing = true
        Hyprland.dispatch('hl.dsp.submap("capture")')
        safety.restart()
        catcher.forceActiveFocus()
    }
    function stopCapture() {
        if (!capturing) return
        capturing = false
        safety.stop()
        Hyprland.dispatch('hl.dsp.submap("reset")')
    }
    function cancel() { stopCapture(); editing = -1; captured = null }
    Timer { id: safety; interval: 10000; onTriggered: page.stopCapture() }
    // Escape in the «capture» submap (or any exit from it): cancelled
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "submap" && event.data !== "capture" && page.capturing) page.cancel() }
    }
    Component.onDestruction: stopCapture()

    // Qt key → Hyprland name
    function keyName(event) {
        const k = event.key
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k)
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k)
        // With Shift, numbers arrive as symbols: the physical key is used (1…0 = 10…19)
        if (event.nativeScanCode >= 10 && event.nativeScanCode <= 19) return String((event.nativeScanCode - 9) % 10)
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1)
        const map = {
            [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "TAB", [Qt.Key_Backtab]: "TAB",
            [Qt.Key_Space]: "SPACE", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
            [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
            [Qt.Key_PageUp]: "Prior", [Qt.Key_PageDown]: "Next", [Qt.Key_Print]: "Print",
            [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
            [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume",
            [Qt.Key_VolumeMute]: "XF86AudioMute", [Qt.Key_MicMute]: "XF86AudioMicMute",
            [Qt.Key_MediaNext]: "XF86AudioNext", [Qt.Key_MediaPrevious]: "XF86AudioPrev",
            [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaPause]: "XF86AudioPause",
            [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        }
        if (map[k]) return map[k]
        // Any other one, by its key code
        return event.nativeScanCode > 0 ? "code:" + event.nativeScanCode : ""
    }

    // --- Save ---
    function save() {
        const b = binds.find(x => x.line === editing)
        if (!b || !captured) return
        const mods = captured.slice(0, -1), key = captured[captured.length - 1]
        const rest = mods.filter(m => m !== "SUPER").concat([key]).join(" + ")
        const expr = mods.includes("SUPER") ? 'mainMod .. " + ' + rest + '"' : '"' + rest + '"'
        const lines = file.text().split("\n")
        const raw = lines[b.line]
        lines[b.line] = raw.slice(0, b.start) + expr + raw.slice(b.end)
        file.setText(lines.join("\n"))
        message = "«" + descView(b.desc) + "»: " + captured.map(prettyKey).join(" + ")
        editing = -1; captured = null
    }
    function nvim(line) {
        Quickshell.execDetached(["alacritty", "--class", "menu-terminal", "--title", "keybinds.lua", "-e",
                                 "nvim", "+" + (line + 1), page.path])
    }

    // --- View ---
    component Keycaps: Row {
        id: caps
        property var parts: []
        spacing: 4
        Repeater {
            model: caps.parts
            delegate: Rectangle {
                required property string modelData
                implicitWidth: Math.max(24, cap.implicitWidth + 14); implicitHeight: 24
                radius: 6
                color: Theme.control
                border.color: Theme.border; border.width: 1
                BarText { id: cap; anchors.centerIn: parent; text: page.prettyKey(modelData); font.pixelSize: 11; color: Theme.fg }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        WifiField {
            search: true
            Layout.fillWidth: true
            placeholder: I18n.tr("Search by action or key (e.g. «screenshot» or «Super + Q»)")
            onTextChanged: page.query = text.toLowerCase()
        }
        Button { icon: ""; text: "keybinds.lua"; onClicked: page.nvim(0) }
        // Receives the keys while capturing (no size: takes no space)
        Item {
            id: catcher
            Layout.preferredWidth: 0; Layout.preferredHeight: 0
            Keys.onPressed: event => {
                event.accepted = true
                if (!page.capturing) return
                const mods = [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R,
                              Qt.Key_AltGr, Qt.Key_CapsLock, Qt.Key_NumLock]
                if (mods.includes(event.key)) return
                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) { page.cancel(); return }
                const name = page.keyName(event)
                if (!name) return
                const parts = []
                if (event.modifiers & Qt.MetaModifier) parts.push("SUPER")
                if (event.modifiers & Qt.ControlModifier) parts.push("CTRL")
                if (event.modifiers & Qt.AltModifier) parts.push("ALT")
                if (event.modifiers & Qt.ShiftModifier) parts.push("SHIFT")
                parts.push(name)
                page.captured = parts
                page.stopCapture()
            }
        }
    }

    BarText {
        visible: page.message !== ""
        text: "󰄬  " + I18n.tr("Saved") + " · " + page.message
        color: Theme.fgSoft
        font.pixelSize: 12
    }

    Repeater {
        model: page.sections
        delegate: SettingsGroup {
            id: group
            required property string modelData
            readonly property var rows: page.binds.filter(b => b.section === modelData && page.matches(b))
            visible: rows.length > 0
            label: I18n.tr(modelData)

            Repeater {
                model: group.rows
                delegate: ColumnLayout {
                    id: row
                    required property var modelData
                    readonly property bool open: page.editing === modelData.line
                    Layout.fillWidth: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        BarText { text: page.descView(row.modelData.desc); Layout.fillWidth: true; elide: Text.ElideRight }
                        Keycaps { parts: row.modelData.parts; opacity: row.open ? 0.4 : 1 }
                        Button {
                            kind: "ghost"
                            icon: row.modelData.editable ? "󰏫" : ""
                            text: row.modelData.editable ? I18n.tr("Change") : "nvim"
                            onClicked: row.modelData.editable ? page.startCapture(row.modelData.line) : page.nvim(row.modelData.line)
                        }
                    }

                    // Change panel
                    Rectangle {
                        visible: row.open
                        Layout.fillWidth: true
                        implicitHeight: panel.implicitHeight + 24
                        radius: 10
                        color: Theme.selSoft
                        border.color: page.capturing ? Theme.sel : Theme.border
                        border.width: 1
                        ColumnLayout {
                            id: panel
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                BarText {
                                    Layout.fillWidth: true
                                    text: page.capturing ? I18n.tr("Press the new combination…  (Esc cancels)")
                                        : page.captured ? I18n.tr("New combination:") : I18n.tr("No combination")
                                    color: page.capturing ? Theme.fg : Theme.fgSoft
                                }
                                Keycaps { visible: !!page.captured; parts: page.captured ?? [] }
                            }
                            BarText {
                                readonly property string clash: page.captured ? page.conflict(page.captured) : ""
                                visible: !!page.captured && (clash !== "" || page.bare(page.captured))
                                text: page.captured && page.bare(page.captured)
                                    ? I18n.tr("Without a modifier, that key could no longer be typed: add Super, Ctrl or Alt")
                                    : I18n.tr("Already used by «%1»: both would run").arg(clash)
                                color: Theme.red
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 8
                                Button {
                                    kind: "primary"
                                    text: page.captured && page.conflict(page.captured) ? I18n.tr("Save anyway") : I18n.tr("Save")
                                    enabled: !!page.captured && !page.bare(page.captured)
                                    onClicked: page.save()
                                }
                                Button { text: I18n.tr("Again"); visible: !page.capturing; onClicked: page.startCapture(row.modelData.line) }
                                Button { kind: "ghost"; text: I18n.tr("Cancel"); onClicked: page.cancel() }
                            }
                        }
                    }
                }
            }
        }
    }

    BarText {
        visible: page.binds.length > 0 && !page.binds.some(b => page.matches(b))
        text: I18n.tr("No keybind matches «%1»").arg(page.query)
        color: Theme.dim
    }
}
