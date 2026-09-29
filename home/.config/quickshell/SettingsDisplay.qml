// Settings → Display: brightness of each monitor (internal through backlight, external through DDC/CI) with
// scripts/brightness.sh, and the layout of each monitor (MonitorForm), saved in
// ~/.config/hypr/conf/monitors.lua. Only the hl.monitor of connected monitors are rewritten;
// those of disconnected ones stay as they were. After applying there are 15 s to confirm or it is undone.
// «Edit in nvim» opens the file; the form reads the real values, so it respects what was edited.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Displays")
    subtitle: I18n.tr("Resolution, scale, position and brightness of each monitor")

    readonly property string monitorsPath: Quickshell.env("HOME") + "/.config/hypr/conf/monitors.lua"
    property var forms: []              // MonitorForm of each connected monitor
    readonly property bool dirty: forms.some(f => f.dirty)
    property string previous: ""        // monitors.lua before applying (to undo)
    property int countdown: 0           // > 0: waiting for confirmation

    // vrr written in the file per monitor (Hyprland only says whether it is active, not whether it is «2»)
    function fileVrr(name) {
        const m = monitorsFile.text().match(new RegExp('output\\s*=\\s*"' + name + '"[^}]*?vrr\\s*=\\s*(\\d)'))
        return m ? parseInt(m[1]) : -1
    }

    // The rollback is done by a separate process: that way it is undone even if Settings is closed or the
    // shell restarts. It keeps the copy and, if not confirmed within 15 s, restores it and reloads.
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string backupPath: runDir + "/monitors.lua.before"
    readonly property string pendingFlag: runDir + "/monitors-pending"

    function apply() {
        const old = monitorsFile.text()
        Quickshell.execDetached(["sh", "-c",
            'printf "%s" "$1" > "$2" && touch "$3" && sleep 15 && [ -e "$3" ] && ' +
            'cp "$2" "$4" && rm -f "$3" && hyprctl reload >/dev/null',
            "sh", old, page.backupPath, page.pendingFlag, page.monitorsPath])
        const done = {}
        const header = "-- Monitors — https://wiki.hypr.land/Configuring/Basics/Monitors/\n" +
            "-- Rewritten by Settings → Displays on apply (only the hl.monitor of connected monitors;\n" +
            "-- the others stay as they are). It can also be edited by hand: the form reads Hyprland's\n" +
            "-- real values. Anything that is not hl.monitor is lost when applying from Settings.\n\n"
        const blocks = []
        for (const b of old.match(/hl\.monitor\(\{[\s\S]*?\}\)/g) ?? []) {
            const out = (b.match(/output\s*=\s*"([^"]+)"/) ?? [])[1]
            const f = page.forms.find(f => f.output === out)
            if (f) { blocks.push(f.block()); done[out] = true } else blocks.push(b)
        }
        for (const f of page.forms) if (!done[f.output]) blocks.push(f.block())
        previous = old
        monitorsFile.setText(header + blocks.join("\n\n") + "\n")
        countdown = 15
    }
    function keep() {
        countdown = 0; previous = ""
        Quickshell.execDetached(["rm", "-f", page.pendingFlag])
    }
    function undo() {
        countdown = 0; previous = ""
        Quickshell.execDetached(["sh", "-c", '[ -e "$1" ] && cp "$2" "$3" && rm -f "$1" && hyprctl reload >/dev/null',
                                 "sh", page.pendingFlag, page.backupPath, page.monitorsPath])
        refreshTimer.restart()
    }

    FileView {
        id: monitorsFile
        path: page.monitorsPath
        blockLoading: true
        // Hyprland reloads the config on save; it is forced just in case and the monitors are reread
        onSaved: reloadProc.running = true
    }
    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        onExited: { Hyprland.refreshMonitors(); refreshTimer.restart() }
    }
    // After reloading, the form reads the real values again
    Timer { id: refreshTimer; interval: 800; onTriggered: { for (const f of page.forms) f.load() } }
    Timer {
        interval: 1000; repeat: true
        running: page.countdown > 0
        onTriggered: if (--page.countdown === 0) refreshTimer.restart()   // the process has already undone it
    }

    // Confirmation after applying
    Rectangle {
        visible: page.countdown > 0
        Layout.fillWidth: true
        implicitHeight: confirmRow.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.selSoft
        border.color: Theme.sel
        border.width: 1
        RowLayout {
            id: confirmRow
            anchors { fill: parent; margins: 12 }
            spacing: 10
            BarText {
                Layout.fillWidth: true
                text: I18n.tr("Keep this configuration? It is undone in %1 s").arg(page.countdown)
                wrapMode: Text.Wrap
            }
            Button { kind: "primary"; text: I18n.tr("Keep"); onClicked: page.keep() }
            Button { text: I18n.tr("Undo"); onClicked: page.undo() }
        }
    }

    // --- Layout: each monitor to scale at its position (with the form's values, before
    // applying). Logical size = resolution / scale (rotated 90° or 270°, swapped). They can be dragged:
    // on release, placeMonitor() snaps it to the edge of the closest monitor ---
    function placeMonitor(i, x, y, thr) {
        const b = map.boxes, me = b[i], others = b.filter((o, j) => j !== i)
        const w = me.w, h = me.h
        const overlaps = (cx, cy) => others.some(o => cx < o.x + o.w - 0.5 && cx + w > o.x + 0.5 && cy < o.y + o.h - 0.5 && cy + h > o.y + 0.5)
        // Along the edge: within the stretch where they touch, and aligned (start, centre, end) if close
        const along = (v, start, len, size) => {
            const lo = start - size + Math.min(size, len) / 4, hi = start + len - Math.min(size, len) / 4
            v = Math.max(lo, Math.min(hi, v))
            for (const a of [start, start + len - size, start + (len - size) / 2]) if (Math.abs(v - a) < thr) return a
            return v
        }
        let best = null
        for (const o of others) {
            const cands = [
                { x: o.x + o.w, y: along(y, o.y, o.h, h) }, { x: o.x - w, y: along(y, o.y, o.h, h) },
                { x: along(x, o.x, o.w, w), y: o.y + o.h }, { x: along(x, o.x, o.w, w), y: o.y - h },
            ]
            for (const c of cands) {
                if (overlaps(c.x, c.y)) continue
                const d = Math.hypot(c.x - x, c.y - y)
                if (!best || d < best.d) best = { x: c.x, y: c.y, d: d }
            }
        }
        const pos = b.map((o, j) => j === i ? (best ?? { x: x, y: y }) : o)
        // So the top-left corner of the whole set ends up at 0,0
        const mx = Math.min(...pos.map(p => p.x)), my = Math.min(...pos.map(p => p.y))
        pos.forEach((p, j) => page.forms[j].setPosition(Math.round(p.x - mx), Math.round(p.y - my)))
    }

    SettingsGroup {
        visible: page.forms.length > 0
        label: I18n.tr("Arrangement")
        Item {
            id: map
            Layout.fillWidth: true
            implicitHeight: 240
            readonly property var boxes: page.forms.map(f => {
                const sz = f.resSize, sc = f.outScale || 1, rot = f.outTransform % 2 === 1
                const w = (rot ? sz[1] : sz[0]) / sc, h = (rot ? sz[0] : sz[1]) / sc
                return { name: f.output, x: f.px, y: f.py, w: w || 1, h: h || 1, res: f.res, scale: f.outScale,
                         focused: f.monitor.focused, dirty: f.dirty }
            })
            readonly property real minX: Math.min(...boxes.map(b => b.x))
            readonly property real minY: Math.min(...boxes.map(b => b.y))
            readonly property real spanW: Math.max(...boxes.map(b => b.x + b.w)) - minX
            readonly property real spanH: Math.max(...boxes.map(b => b.y + b.h)) - minY
            // With room around it to drag a monitor to the other side (with just one, without it)
            readonly property real room: boxes.length > 1 ? 1.7 : 1
            readonly property real k: boxes.length ? Math.min((width - 8) / (spanW * room), (height - 8) / (spanH * (boxes.length > 1 ? 1.4 : 1))) : 1
            readonly property real offX: (width - spanW * k) / 2
            readonly property real offY: (height - spanH * k) / 2
            Repeater {
                model: map.boxes
                delegate: Rectangle {
                    id: box
                    required property var modelData
                    required property int index
                    x: map.offX + (modelData.x - map.minX) * map.k
                    y: map.offY + (modelData.y - map.minY) * map.k
                    z: dragArea.drag.active ? 1 : 0
                    width: Math.max(8, modelData.w * map.k - 3)
                    height: Math.max(8, modelData.h * map.k - 3)
                    radius: 8
                    color: dragArea.drag.active ? Theme.controlHi : modelData.focused ? Theme.selSoft : Theme.control
                    border.color: modelData.dirty || dragArea.drag.active ? Theme.fg : modelData.focused ? Theme.sel : Theme.border
                    border.width: modelData.dirty || dragArea.drag.active ? 2 : 1
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        BarText { anchors.horizontalCenter: parent.horizontalCenter; text: box.modelData.name; font.bold: true; font.pixelSize: 12 }
                        BarText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: box.modelData.res + " · " + (Math.round(box.modelData.scale * 100) / 100).toLocaleString(I18n.locale, "g", 3) + "×"
                            color: Theme.dim; font.pixelSize: 10
                        }
                    }
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        enabled: map.boxes.length > 1
                        cursorShape: dragArea.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true          // so the page's Flickable does not take it
                        drag.target: box
                        drag.threshold: 4
                        drag.minimumX: 0; drag.maximumX: map.width - box.width
                        drag.minimumY: 0; drag.maximumY: map.height - box.height
                        onReleased: {
                            if (!dragArea.drag.active) return
                            page.placeMonitor(box.index, (box.x - map.offX) / map.k + map.minX,
                                              (box.y - map.offY) / map.k + map.minY, 24 / map.k)
                            // If nothing changes (dropped in the same spot), the diagram is not rebuilt:
                            // it goes back to following its monitor
                            box.x = Qt.binding(() => map.offX + (box.modelData.x - map.minX) * map.k)
                            box.y = Qt.binding(() => map.offY + (box.modelData.y - map.minY) * map.k)
                        }
                    }
                }
            }
        }
        BarText {
            text: I18n.tr("Drag a monitor to change its position: on release it snaps to the edge of the closest one. In red, the focused one; with a white border, the one with unapplied changes.")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
    }

    Repeater {
        model: Hyprland.monitors.values

        delegate: SettingsGroup {
            id: mon
            required property var modelData
            readonly property var info: modelData.lastIpcObject
            readonly property bool external: !modelData.name.startsWith("eDP")
            property int brightness: -1          // -1: reading · -2: no control
            label: modelData.name + (info?.description ? "  ·  " + info.description : "")

            Process {
                id: getProc
                running: true
                command: [Quickshell.shellPath("scripts/brightness.sh"), "get", mon.modelData.name]
                stdout: StdioCollector {
                    onStreamFinished: { const p = parseInt(text); if (!isNaN(p)) mon.brightness = p }
                }
                onExited: code => { if (code !== 0) mon.brightness = -2 }
            }
            // Sending while dragging: a single process at a time and always the
            // latest value (DDC/CI takes ~0.15 s per change).
            property int pending: -1
            function push(v) {
                pending = v
                if (!setProc.running) sendNext()
            }
            function sendNext() {
                if (pending < 0) return
                setProc.command = [Quickshell.shellPath("scripts/brightness.sh"), "set", pending + "%", modelData.name]
                pending = -1
                setProc.running = true
            }
            Process { id: setProc; onExited: mon.sendNext() }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: mon.brightness >= 0
                BarText { text: "󰃠"; font.pixelSize: 16 }
                SliderField {
                    fill: true
                    from: mon.external ? 0 : 1; to: 100
                    suffix: "%"
                    value: Math.max(0, mon.brightness)
                    onMoved: v => { mon.brightness = v; mon.push(v) }
                }
            }
            BarText {
                visible: mon.brightness < 0
                text: mon.brightness === -1 ? I18n.tr("Reading brightness…")
                    : I18n.tr("Brightness not available: ddcutil and DDC/CI enabled in the monitor's menu are needed")
                color: Theme.dim
                font.pixelSize: 11
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            BarText {
                text: (mon.info ? I18n.tr("%1 at %2 Hz · scale %3").arg(`${mon.info.width}×${mon.info.height}`).arg(Math.round(mon.info.refreshRate)).arg(mon.info.scale) : "")
                    + (mon.modelData.focused ? "  ·  " + I18n.tr("focused") : "")
                color: Theme.dim
                font.pixelSize: 11
            }

            MonitorForm {
                monitor: mon.modelData
                fileVrr: page.fileVrr(mon.modelData.name)
                Component.onCompleted: page.forms = page.forms.concat([this])
                Component.onDestruction: page.forms = page.forms.filter(f => f !== this)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Button {
            kind: "primary"; text: I18n.tr("Apply")
            enabled: page.dirty && page.countdown === 0
            onClicked: page.apply()
        }
        Button {
            text: I18n.tr("Discard changes")
            visible: page.dirty
            onClicked: { for (const f of page.forms) f.load() }
        }
        Item { Layout.fillWidth: true }
        Button {
            icon: ""; text: I18n.tr("Edit in nvim")
            onClicked: Terminal.open("monitors.lua", ["nvim", page.monitorsPath])
        }
    }

    BarText {
        text: I18n.tr("The brightness keys act on the focused monitor. The layout is saved in ~/.config/hypr/conf/monitors.lua; disconnected monitors keep whatever they had.")
        color: Theme.dim
        font.pixelSize: 11
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}
