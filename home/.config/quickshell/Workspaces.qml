// Workspaces: always 1 to 5, plus any higher ones that exist; the same on
// every bar. Click to go to one.
//   red fill: active on this screen (like the selected option in Settings and the menu)
//   red border: visible on another
//   normal text: with windows · dimmed: empty
import Quickshell
import Quickshell.Hyprland
import QtQuick

Row {
    id: root
    required property var targetScreen
    readonly property var monitor: Hyprland.monitorFor(targetScreen)
    readonly property int minCount: 5
    spacing: 4

    // Workspaces that exist now (id > 0), by id
    readonly property var existing: {
        const m = {}
        for (const w of Hyprland.workspaces.values) if (w.id > 0) m[w.id] = w
        return m
    }
    readonly property var ids: {
        const s = new Set(Array.from({ length: minCount }, (_, i) => i + 1))
        for (const id in existing) s.add(Number(id))
        return Array.from(s).sort((a, b) => a - b)
    }

    Repeater {
        model: root.ids

        delegate: Rectangle {
            required property int modelData
            readonly property var ws: root.existing[modelData] ?? null
            readonly property bool here: root.monitor?.activeWorkspace?.id === modelData
            readonly property bool elsewhere: !here && Hyprland.monitors.values.some(m => m.activeWorkspace?.id === modelData)
            readonly property bool occupied: (ws?.toplevels?.values?.length ?? 0) > 0

            width: here ? 30 : 22
            height: 22
            radius: 11
            color: here ? Theme.sel : Theme.surface
            border.width: elsewhere ? 1.5 : 0
            border.color: Theme.sel
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            BarText {
                anchors.centerIn: parent
                text: modelData
                color: here ? Theme.selText : occupied || elsewhere ? Theme.fg : Theme.dim
                font.pixelSize: 11
                font.bold: here
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${modelData} })`)
            }
        }
    }
}
