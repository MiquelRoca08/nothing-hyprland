// Form for one monitor (Settings → Display): resolution, refresh rate, scale, position, rotation,
// VRR and 10-bit color. It starts from Hyprland's real values (so it respects what was edited by hand
// in monitors.lua) and block() returns its hl.monitor({…}). SettingsDisplay applies it.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var monitor          // HyprlandMonitor
    property int fileVrr: -1               // vrr written in monitors.lua (Hyprland only says yes/no)
    readonly property var info: monitor.lastIpcObject
    readonly property string output: monitor.name
    property bool dirty: false
    Layout.fillWidth: true
    spacing: 12

    // Form state
    property string res: ""
    property string rate: ""
    property real outScale: 1
    property int px: 0
    property int py: 0
    property int outTransform: 0
    property int vrr: 0
    property bool tenBit: false

    // Available modes: «2880x1800@120.00Hz» → resolutions (in their order) and the refresh rates of each
    readonly property var modes: (info?.availableModes ?? []).map(m => {
        const [r, hz] = m.replace(/Hz$/, "").split("@")
        return { res: r, rate: hz }
    })
    readonly property var resolutions: [...new Set(modes.map(m => m.res))]
    readonly property var rates: modes.filter(m => m.res === res).map(m => m.rate)
    // Scales that fit the chosen resolution: multiples of 1/120 (Wayland fractional-scale)
    // that give an integer logical size, between 1 and 3. Of those, the «round» ones (two decimals or thirds:
    // 1.8 yes, 1.0667 no). If the current one does not fit (e.g. 1.75 on 2880×1800), it is added so it shows.
    readonly property var resSize: res ? res.split("x").map(Number) : [0, 0]
    function fits(s) {
        const [w, h] = resSize, k = Math.round(s * 120)
        return Math.abs(k - s * 120) < 1e-3 && (w * 120) % k === 0 && (h * 120) % k === 0
    }
    readonly property var scales: {
        const [w, h] = resSize, out = []
        for (let k = 120; k <= 360; k++) {
            if ((w * 120) % k || (h * 120) % k) continue
            const v = Math.round(k / 120 * 1e6) / 1e6
            const nice = x => Math.abs(Math.round(x) - x) < 1e-4
            if (nice(v * 100) || nice(v * 3)) out.push(v)
        }
        if (!out.length) out.push(1)
        return out.includes(outScale) ? out : out.concat([outScale]).sort((a, b) => a - b)
    }
    function scaleText(s) { return (Math.round(s * 100) / 100).toString().replace(".", I18n.locale.decimalPoint) + "×" }

    function load() {
        const i = info
        if (!i) return
        res = `${i.width}x${i.height}`
        const same = modes.filter(m => m.res === res)
        const near = same.reduce((a, m) => Math.abs(m.rate - i.refreshRate) < Math.abs(a.rate - i.refreshRate) ? m : a,
                                 same[0] ?? { rate: i.refreshRate.toFixed(2) })
        rate = near.rate
        outScale = Math.round(i.scale * 1e6) / 1e6
        px = i.x; py = i.y
        // The fields are filled by hand (a binding would break when typing in them)
        posX.text = px; posY.text = py
        outTransform = i.transform
        vrr = fileVrr >= 0 ? fileVrr : (i.vrr ? 1 : 0)
        tenBit = (i.currentFormat ?? "").includes("2101010")
        dirty = false
    }
    Component.onCompleted: load()
    // New position from the diagram in Settings → Displays (dragging)
    function setPosition(x, y) {
        if (x === px && y === py) return
        px = x; py = y
        posX.text = x; posY.text = y
        dirty = true
    }

    function block() {
        return "hl.monitor({\n" +
            `    output    = "${output}",\n` +
            `    mode      = "${res}@${rate}",\n` +
            `    position  = "${px}x${py}",\n` +
            `    scale     = ${outScale},\n` +
            `    transform = ${outTransform},\n` +
            `    vrr       = ${vrr},\n` +
            `    bitdepth  = ${tenBit ? 10 : 8},\n` +
            "})"
    }

    SettingsRow {
        text: I18n.tr("Resolution")
        Stepper {
            items: root.resolutions.map(r => r.replace("x", "×"))
            index: Math.max(0, root.resolutions.indexOf(root.res))
            onMoved: i => {
                root.res = root.resolutions[i]
                // The highest refresh rate that resolution supports
                root.rate = root.rates.reduce((a, r) => parseFloat(r) > parseFloat(a) ? r : a, root.rates[0])
                root.dirty = true
            }
        }
    }
    SettingsRow {
        text: I18n.tr("Refresh rate")
        Stepper {
            items: root.rates.map(r => Math.round(parseFloat(r)) + " Hz")
            index: Math.max(0, root.rates.indexOf(root.rate))
            onMoved: i => { root.rate = root.rates[i]; root.dirty = true }
        }
    }
    SettingsRow {
        text: I18n.tr("Scale")
        description: root.fits(root.outScale)
            ? I18n.tr("Logical size: %1 × %2").arg(Math.round(root.resSize[0] / root.outScale)).arg(Math.round(root.resSize[1] / root.outScale))
            : I18n.tr("It does not fit this resolution: Hyprland will change it to the closest one")
        Stepper {
            items: root.scales.map(s => root.scaleText(s))
            index: Math.max(0, root.scales.indexOf(root.outScale))
            onMoved: i => { root.outScale = root.scales[i]; root.dirty = true }
        }
    }
    SettingsRow {
        text: I18n.tr("Position")
        description: I18n.tr("Top-left corner in logical pixels (x, y)")
        RowLayout {
            spacing: 6
            WifiField {
                id: posX
                Layout.preferredWidth: 90
                onTextChanged: { const n = parseInt(text); if (!isNaN(n) && n !== root.px) { root.px = n; root.dirty = true } }
            }
            WifiField {
                id: posY
                Layout.preferredWidth: 90
                onTextChanged: { const n = parseInt(text); if (!isNaN(n) && n !== root.py) { root.py = n; root.dirty = true } }
            }
        }
    }
    SettingsRow {
        text: I18n.tr("Rotation")
        ChoiceChips {
            options: [{ v: 0, label: "0°" }, { v: 1, label: "90°" }, { v: 2, label: "180°" }, { v: 3, label: "270°" }]
            value: root.outTransform
            onChosen: v => { root.outTransform = v; root.dirty = true }
        }
    }
    SettingsRow {
        text: I18n.tr("Variable refresh rate (VRR)")
        ChoiceChips {
            options: [{ v: 0, label: I18n.tr("No") }, { v: 1, label: I18n.tr("Yes") }, { v: 2, label: I18n.tr("Fullscreen only") }]
            value: root.vrr
            onChosen: v => { root.vrr = v; root.dirty = true }
        }
    }
    SettingsRow {
        text: I18n.tr("10-bit color")
        Toggle { checked: root.tenBit; onToggled: { root.tenBit = !root.tenBit; root.dirty = true } }
    }
}
