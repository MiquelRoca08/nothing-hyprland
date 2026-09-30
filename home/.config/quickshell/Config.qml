pragma Singleton
// Persistent shell settings (edited by the Settings window), saved
// in settings.json. Part of them is applied outside the shell, generating files that
// must not be edited by hand:
//   ~/.config/hypr/conf/shell-settings.lua → gaps, rounding, keyboard, mouse and touchpad
//                                            (Hyprland reloads it by itself on change)
//   ~/.config/hypr/hypridle.conf           → lock, screen and suspend timeouts
//                                            (hypridle is restarted to apply it)
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property alias options: adapter

    readonly property var defaults: ({
        barStyle: "float", gap: 10, radius: 12, screenRadius: 18, wallpaperTone: 26,
        wallpaperMode: "dots", wallpaperPath: "",
        barMedia: true, barDate: true, barTray: true, barSystem: true, barNetwork: true, barVolume: true,
        barMic: true, barBattery: true, clockSeconds: false,
        barOrder: { left: ["workspaces", "media"], center: ["clock"],
                    right: ["tray", "system", "network", "mic", "volume", "battery", "notifications", "settings", "power"] }
    })
    // Modules that can be placed on the bar; opt = key that shows or hides it (if any)
    readonly property var barModules: [
        { k: "workspaces",    label: "Workspaces" },
        { k: "media",         label: "Media player",        opt: "barMedia" },
        { k: "clock",         label: "Date and time" },
        { k: "tray",          label: "System tray",         opt: "barTray" },
        { k: "system",        label: "System monitor",      opt: "barSystem" },
        { k: "network",       label: "Network",             opt: "barNetwork" },
        { k: "mic",           label: "Microphone",          opt: "barMic" },
        { k: "volume",        label: "Volume",              opt: "barVolume" },
        { k: "battery",       label: "Battery",             opt: "barBattery" },
        { k: "notifications", label: "Notifications" },
        { k: "settings",      label: "Settings" },
        { k: "power",         label: "Power menu" },
    ]
    readonly property var barSections: ["left", "center", "right"]

    // Sections of the Settings window, as a tree (labels in English: shown through I18n.tr): categories (children) and pages (file). Pages
    // without their own file show SettingsSoon.qml with what is planned (soon).
    // New section: add it here (the key k is the one in `qs ipc call settings open <k>`). needs: the
    // package without which the page is hidden (see installedNeeds).
    readonly property var settingsTree: [
        { k: "home", icon: "󰋜", label: "Home", file: "SettingsHome.qml" },
        { k: "system", icon: "󰍹", label: "System", children: [
            { k: "display",       icon: "󰍹", label: "Displays",        file: "SettingsDisplay.qml" },
            { k: "sound",         icon: "󰕾", label: "Sound",           file: "SettingsSound.qml" },
            { k: "input",         icon: "󰌌", label: "Keyboard and mouse", file: "SettingsInput.qml" },
            { k: "notifications", icon: "󰂚", label: "Notifications",   file: "SettingsNotifications.qml" },
            { k: "battery",       icon: "󰂄", label: "Battery",         file: "SettingsPower.qml" },
            { k: "storage",       icon: "󰋊", label: "Storage",           file: "SettingsStorage.qml" },
            { k: "keybinds",      icon: "󰌓", label: "Keybinds",          file: "SettingsKeybinds.qml" },
            { k: "language",      icon: "󰗊", label: "Language",          file: "SettingsLanguage.qml" },
        ] },
        { k: "connections", icon: "󰛳", label: "Connections", children: [
            { k: "wifi",      icon: "󰤨", label: "Wi-Fi",      file: "SettingsWifi.qml" },
            { k: "bluetooth", icon: "󰂯", label: "Bluetooth",  file: "SettingsBluetooth.qml", needs: "bluez" },
            { k: "printers",  icon: "󰐪", label: "Printers",   file: "SettingsPrinters.qml", needs: "cups" },
        ] },
        { k: "personalization", icon: "󰏘", label: "Personalization", children: [
            { k: "wallpaper", icon: "󰸉", label: "Wallpaper",         file: "SettingsWallpaper.qml" },
            { k: "themes",    icon: "󰏘", label: "Themes",            file: "SettingsThemes.qml" },
            { k: "quickshell", icon: "󰕮", label: "QuickShell", children: [
                { k: "menu", icon: "󰍜", label: "Menu", file: "SettingsMenu.qml" },
                { k: "lock", icon: "󰌾", label: "Lock screen",         file: "SettingsIdle.qml" },
                { k: "bar",  icon: "󰕮", label: "Bar",                 file: "SettingsBar.qml" },
            ] },
            { k: "fonts",    icon: "󰛖", label: "Fonts",             file: "SettingsFonts.qml" },
            { k: "hyprland", icon: "󰈙", label: "Hyprland",          file: "SettingsHyprland.qml" },
        ] },
        { k: "apps", icon: "󰀻", label: "Apps", children: [
            { k: "apps-installed", icon: "󰏗", label: "Installed",  file: "SettingsAppsInstalled.qml" },
            { k: "apps-install",   icon: "󰏔", label: "Install",    file: "SettingsAppsInstall.qml" },
        ] },
        { k: "updates", icon: "󰚰", label: "Updates", file: "SettingsUpdates.qml" },
    ]
    // Old keys (IPC, walker menu) → the new ones
    readonly property var settingsAliases: ({ power: "battery", idle: "lock", appearance: "themes", todo: "home" })
    // Which of the packages the pages need (needs) are installed: null until known (everything shown).
    // Checked on start, when Settings opens and after its terminals (installing or removing packages;
    // the installer's features module removes Bluetooth and CUPS, for example)
    property var installedNeeds: null
    function checkNeeds() { if (!needsProc.running) needsProc.running = true }
    Process {
        id: needsProc
        running: true
        command: ["sh", "-c", "pacman -Qq \"$@\" 2>/dev/null; true", "sh"].concat(
            root.settingsTreeAll().filter(e => e.needs).map(e => e.needs))
        stdout: StdioCollector { onStreamFinished: root.installedNeeds = text.split("\n").filter(l => l) }
    }
    Connections {
        target: ShellState
        function onSettingsOpenChanged() { if (ShellState.settingsOpen) root.checkNeeds() }
        function onSettingsChanged() { root.checkNeeds() }
    }
    function settingsTreeAll() {
        const out = []
        const walk = list => { for (const e of list) { out.push(e); if (e.children) walk(e.children) } }
        walk(settingsTree)
        return out
    }
    // The tree without the pages whose package is missing (and without categories left empty)
    readonly property var settingsVisible: {
        const have = installedNeeds
        const prune = list => list.map(e => e.children ? Object.assign({}, e, { children: prune(e.children) }) : e)
            .filter(e => e.children ? e.children.length > 0 : !e.needs || have === null || have.includes(e.needs))
        return prune(settingsTree)
    }
    // Every entry, in order, with its level (0, 1, 2) and the chain of categories containing it
    readonly property var settingsFlat: {
        const out = []
        const walk = (list, depth, parents) => {
            for (const e of list) {
                out.push(Object.assign({ depth: depth, parents: parents }, e))
                if (e.children) walk(e.children, depth + 1, parents.concat([e.k]))
            }
        }
        walk(settingsVisible, 0, [])
        return out
    }
    // Page (leaf) for a key: its own, the first of a category, or Home
    function settingsEntry(k) {
        // First the key as is; the old ones only if it does not exist (system is now a category)
        let i = settingsFlat.findIndex(e => e.k === k)
        if (i < 0 && settingsAliases[k]) i = settingsFlat.findIndex(e => e.k === settingsAliases[k])
        if (i < 0) return settingsFlat[0]
        for (let j = i; j < settingsFlat.length; j++) if (!settingsFlat[j].children) return settingsFlat[j]
        return settingsFlat[0]
    }

    // Sanitized bar order: no duplicates or unknown keys. Whatever is missing (a new module that
    // is not in settings.json yet) goes after the one before it in the default order, if it is in
    // that zone; otherwise, at its end
    readonly property var barLayout: {
        const known = barModules.map(m => m.k), seen = new Set(), out = {}
        for (const s of barSections) {
            out[s] = (adapter.barOrder?.[s] || []).filter(k => known.includes(k) && !seen.has(k) && seen.add(k))
        }
        for (const k of known) {
            if (seen.has(k)) continue
            const s = barSections.find(z => defaults.barOrder[z].includes(k)) ?? "right"
            const d = defaults.barOrder[s], prev = d.slice(0, d.indexOf(k)).reverse().find(p => out[s].includes(p))
            out[s].splice(prev ? out[s].indexOf(prev) + 1 : out[s].length, 0, k)
        }
        return out
    }
    // Places a module in zone s, at position i (counted with it still in its place)
    function placeBarItem(k, s, i) {
        const lay = {}
        for (const z of barSections) lay[z] = barLayout[z].slice()
        const from = barSections.find(z => lay[z].includes(k))
        const j = lay[from].indexOf(k)
        if (from === s && (i === j || i === j + 1)) return
        lay[from].splice(j, 1)
        if (from === s && j < i) i--
        lay[s].splice(i, 0, k)
        adapter.barOrder = lay         // at once: every assignment saves and reloads the file
    }
    // The system menu's table (~/.local/bin/menu) used to be in Spanish, and its paths and texts are
    // the keys of menuHidden, menuOrder and the path of menuCustom: rename the old ones once. The
    // fields of menuCustom were Spanish too ({ ruta, icono, texto, comando } → { path, icon, text, command })
    readonly property var oldMenuNames: ({
        "Aprender": "Learn", "Acciones": "Actions", "Estilo": "Style", "Ajustes": "Settings",
        "Instalar": "Install", "Quitar": "Remove", "Actualizar": "Update", "Acerca de": "About",
        "Sistema": "System", "Atajos": "Keybinds", "Captura": "Screenshot", "Grabar": "Record",
        "No molestar": "Do Not Disturb", "Bloqueo por inactividad": "Idle lock",
        "Pantalla del portátil": "Laptop screen", "Pantalla": "Screen", "Zona": "Region",
        "Ventana": "Window", "Texto (OCR)": "Text (OCR)", "Sin audio": "No audio",
        "Con audio del sistema": "With system audio", "Con audio y micro": "With audio and mic",
        "Fondo": "Wallpaper", "Apariencia": "Appearance", "Paquete": "Package",
        "Sistema (con AUR)": "System (with AUR)", "Solo repos": "Repos only",
        "Reiniciar walker": "Restart walker", "Reiniciar shell": "Restart shell", "Bloquear": "Lock",
        "Suspender": "Suspend", "Cerrar sesión": "Log out", "Reiniciar": "Reboot", "Apagar": "Power off",
    })
    function migrateMenu() {
        const path = p => p.split("/").map(x => oldMenuNames[x] ?? x).join("/")
        const same = (a, b) => JSON.stringify(a) === JSON.stringify(b)
        const hidden = (adapter.menuHidden ?? []).map(path)
        const order = (adapter.menuOrder ?? []).map(path)
        const custom = (adapter.menuCustom ?? []).map(c => ({
            path: path(c.path ?? c.ruta ?? ""), icon: c.icon ?? c.icono ?? "",
            text: c.text ?? c.texto ?? "", command: c.command ?? c.comando ?? "" }))
        if (!same(hidden, adapter.menuHidden ?? [])) adapter.menuHidden = hidden
        if (!same(order, adapter.menuOrder ?? [])) adapter.menuOrder = order
        if (!same(custom, adapter.menuCustom ?? [])) adapter.menuCustom = custom
    }

    // Resets the given keys to their default values
    function reset(keys) {
        for (const k of keys) if (k in defaults) adapter[k] = defaults[k]
    }

    FileView {
        id: file
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: { writeAdapter(); applyTimer.restart() }
        onLoaded: { root.migrateMenu(); applyTimer.restart() }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }

        JsonAdapter {
            id: adapter
            // Appearance
            property string barStyle: "float"      // "float" | "hug"
            property int gap: 10                   // gaps: Hyprland's gaps_out and the bar's
            property int radius: 12                // rounding of windows, bar and panels
            property int screenRadius: 18          // screen corners
            property int wallpaperTone: 26         // background grey (0-255)
            property string wallpaperMode: "dots"  // "dots" (dot grid) | "image"
            property string wallpaperPath: ""      // background image (in ~/Pictures/Wallpapers)
            // Bar modules
            property bool barMedia: true
            property bool barDate: true
            property bool barTray: true
            property bool barSystem: true
            property bool barNetwork: true
            property bool barVolume: true
            property bool barMic: true
            property bool barBattery: true
            property bool clockSeconds: false
            // Order of the modules in each bar zone (see barModules)
            property var settingsOrder: []         // no longer used (order of the old Settings sidebar)
            // System menu (~/.local/bin/menu reads them with jq): hidden ones («Section» or
            // «Section/Option»), section order and custom entries { path, icon, text, command }
            property var menuHidden: []
            property var menuOrder: []
            property var menuCustom: []
            property var barOrder: ({ left: ["workspaces", "media"], center: ["clock"],
                                      right: ["tray", "system", "network", "mic", "volume", "battery", "notifications", "settings", "power"] })
            // Keyboard, mouse and touchpad (Hyprland)
            property string kbLayout: "es"
            property int repeatRate: 40            // keystrokes/s
            property int repeatDelay: 250          // ms
            property real mouseSensitivity: 0.35   // -1 … 1
            property bool naturalScroll: true      // touchpad
            property bool tapToClick: true
            property bool disableWhileTyping: true
            property real touchpadScroll: 0.1      // touchpad scroll speed
            property string kbVariant: ""          // e.g. «nodeadkeys»
            property string kbOptions: ""          // XKB options, e.g. «caps:escape»
            property bool numlock: true            // Num Lock on at startup
            property int followMouse: 1            // 0 no · 1 focus follows the mouse · 2 only on click
            property string accelProfile: "flat"   // "flat" (no acceleration) | "adaptive"
            property bool leftHanded: false
            property bool mouseNaturalScroll: false
            property bool clickfinger: true        // touchpad: click with 1/2/3 fingers = left/right/middle
            property int drag3fg: 1                // 3-finger drag: 0 no · 1 yes · 2 with 4 fingers
            property bool tapAndDrag: true
            property bool dragLock: false
            property bool middleEmulation: false   // middle click with both buttons at once
            // Lock and idle (hypridle); 0 = never
            property int lockMinutes: 5
            property int screenOffMinutes: 10
            property int suspendMinutes: 0
            // Notifications
            property bool dnd: false               // Do Not Disturb
        }
    }

    // Applies what lives outside the shell (only rewrites if something changes)
    Timer {
        id: applyTimer
        interval: 300
        onTriggered: { root.writeHyprland(); root.writeHypridle() }
    }

    function writeHyprland() {
        const o = adapter
        const text =
            "-- Generated by the shell (Settings → Appearance and Keyboard and mouse). Do not edit by hand:\n" +
            "-- it is overwritten when the settings change. Source: ~/.config/quickshell/settings.json\n\n" +
            "hl.config({\n" +
            `    general    = { gaps_in = ${Math.floor(o.gap / 2)}, gaps_out = ${o.gap} },\n` +
            `    decoration = { rounding = ${o.radius} },\n` +
            "    input = {\n" +
            `        kb_layout          = "${o.kbLayout}",\n` +
            `        kb_variant         = "${o.kbVariant.replace(/"/g, "")}",\n` +
            `        kb_options         = "${o.kbOptions.replace(/"/g, "")}",\n` +
            `        numlock_by_default = ${o.numlock},\n` +
            `        repeat_rate        = ${o.repeatRate},\n` +
            `        repeat_delay       = ${o.repeatDelay},\n` +
            `        sensitivity        = ${o.mouseSensitivity.toFixed(2)},\n` +
            `        accel_profile      = "${o.accelProfile}",\n` +
            `        follow_mouse       = ${o.followMouse},\n` +
            `        left_handed        = ${o.leftHanded},\n` +
            `        natural_scroll     = ${o.mouseNaturalScroll},\n` +
            "        touchpad = {\n" +
            `            natural_scroll          = ${o.naturalScroll},\n` +
            `            tap_to_click            = ${o.tapToClick},\n` +
            `            disable_while_typing    = ${o.disableWhileTyping},\n` +
            `            scroll_factor           = ${o.touchpadScroll.toFixed(2)},\n` +
            `            clickfinger_behavior    = ${o.clickfinger},\n` +
            `            drag_3fg                = ${o.drag3fg},\n` +
            `            tap_and_drag            = ${o.tapAndDrag},\n` +
            `            drag_lock               = ${o.dragLock},\n` +
            `            middle_button_emulation = ${o.middleEmulation},\n` +
            "        },\n" +
            "    },\n" +
            "})\n"
        if (hyprFile.text() !== text) hyprFile.setText(text)
    }

    function writeHypridle() {
        const o = adapter
        let text =
            "# Generated by the shell (Settings → Lock and idle). Do not edit by hand:\n" +
            "# it is overwritten when the settings change. Source: ~/.config/quickshell/settings.json\n\n" +
            "general {\n" +
            "    lock_cmd = lock-screen\n" +
            "    inhibit_sleep = 3\n" +     // suspend only once the lock screen is up
            "    before_sleep_cmd = loginctl lock-session\n" +
            // On wake, the lock screen tries the face again (it locked with the lid closed)
            "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'; qs ipc call lock retry\n" +
            "}\n"
        if (o.lockMinutes > 0)
            text += `\nlistener {\n    timeout = ${o.lockMinutes * 60}\n    on-timeout = loginctl lock-session\n}\n`
        if (o.screenOffMinutes > 0)
            text += `\nlistener {\n    timeout = ${o.screenOffMinutes * 60}\n` +
                    "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'\n" +
                    "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'\n}\n"
        if (o.suspendMinutes > 0)
            text += `\nlistener {\n    timeout = ${o.suspendMinutes * 60}\n    on-timeout = systemctl suspend\n}\n`
        if (idleFile.text() !== text) {
            idleRestartPending = true
            idleFile.setText(text)       // writing is asynchronous: restarted in onSaved
        }
    }

    FileView {
        id: hyprFile
        path: Quickshell.env("HOME") + "/.config/hypr/conf/shell-settings.lua"
        blockLoading: true
        printErrors: false
    }
    // hypridle only reads its config on startup: it is restarted once the file is
    // saved (restarted earlier, it reads the old version)
    property bool idleRestartPending: false
    FileView {
        id: idleFile
        path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
        blockLoading: true
        printErrors: false
        onSaved: {
            if (!root.idleRestartPending) return
            root.idleRestartPending = false
            Quickshell.execDetached(["sh", "-c", "pkill -x hypridle; sleep 0.3; hypridle >/dev/null 2>&1 &"])
        }
    }
}
