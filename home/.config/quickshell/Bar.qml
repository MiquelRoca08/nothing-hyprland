// Top bar (one per monitor). Style according to Theme.barStyle:
//   hug   → attached to the edge, full width; ScreenCorners rounds below it
//   float → floating, with a margin and rounded corners
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt.labs.qmlmodels

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    readonly property bool hug: Theme.barStyle === "hug"

    anchors { top: true; left: true; right: true }
    margins {
        top: bar.hug ? 0 : Theme.gap
        left: bar.hug ? 0 : Theme.gap
        right: bar.hug ? 0 : Theme.gap
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "qs-bar"

    // Module dragging (BarDrag): while it lasts, a copy of the module follows the pointer and a line
    // marks the closest slot in any of the three zones; on release the order is saved
    property string dragKey: ""
    property Item dragItem: null
    property real dragX: 0          // pointer x (bar coordinates)
    property real grabDX: 0         // distance from the pointer to the module's left edge when grabbed
    property var drop: null         // { s, i, x }

    function startDrag(key, item, x) {
        dragKey = key; dragItem = item
        grabDX = x - item.mapToItem(null, 0, 0).x
        moveDrag(x)
    }
    function moveDrag(x) { dragX = x; drop = dropFor(x) }
    function endDrag() {
        const k = dragKey, d = drop
        dragKey = ""; dragItem = null; drop = null      // before reordering: the module is destroyed
        if (k && d) Config.placeBarItem(k, d.s, d.i)
    }
    // Closest slot to x: before or after each visible module, or the spot of an empty zone
    function dropFor(x) {
        const zones = [
            { s: "left", rep: leftRep, row: leftRow, anchor: leftRow.x },
            { s: "center", rep: centerRep, row: centerRow, anchor: content.width / 2 },
            { s: "right", rep: rightRep, row: rightRow, anchor: rightRow.x + rightRow.width },
        ]
        let best = null
        const cand = (s, i, cx) => { if (!best || Math.abs(cx - x) < Math.abs(best.x - x)) best = { s, i, x: cx } }
        for (const z of zones) {
            let any = false
            for (let i = 0; i < z.rep.count; i++) {
                const it = z.rep.itemAt(i)
                if (!it || !it.visible) continue
                any = true
                const l = it.mapToItem(null, 0, 0).x, gap = z.row.spacing / 2
                cand(z.s, i, l - gap)
                cand(z.s, i + 1, l + it.width + gap)
            }
            if (!any) cand(z.s, z.rep.count, z.anchor)
        }
        return best
    }

    // One module per key (list and names in Config.barModules)
    DelegateChooser {
        id: modules
        role: "k"
        DelegateChoice { roleValue: "workspaces"; Workspaces { targetScreen: bar.screen; BarDrag { key: "workspaces"; panel: bar } } }
        DelegateChoice { roleValue: "media"; Media { enabledInBar: Config.options.barMedia; BarDrag { key: "media"; panel: bar } } }
        DelegateChoice { roleValue: "clock"; Clock { BarDrag { key: "clock"; panel: bar } } }
        DelegateChoice { roleValue: "tray"; Tray { visible: Config.options.barTray && items.length > 0; BarDrag { key: "tray"; panel: bar } } }
        DelegateChoice { roleValue: "system"; SystemMonitor { visible: Config.options.barSystem; BarDrag { key: "system"; panel: bar } } }
        DelegateChoice { roleValue: "network"; Network { visible: Config.options.barNetwork; BarDrag { key: "network"; panel: bar } } }
        DelegateChoice { roleValue: "mic"; Mic { visible: Config.options.barMic; BarDrag { key: "mic"; panel: bar } } }
        DelegateChoice { roleValue: "volume"; Volume { visible: Config.options.barVolume; BarDrag { key: "volume"; panel: bar } } }
        DelegateChoice { roleValue: "battery"; Battery { visible: Config.options.barBattery && (dev?.isLaptopBattery ?? false); BarDrag { key: "battery"; panel: bar } } }
        DelegateChoice { roleValue: "notifications"; NotificationButton { BarDrag { key: "notifications"; panel: bar } } }
        DelegateChoice { roleValue: "settings"; SettingsButton { BarDrag { key: "settings"; panel: bar } } }
        DelegateChoice { roleValue: "power"; PowerButton { BarDrag { key: "power"; panel: bar } } }
    }

    Rectangle {
        id: content
        anchors.fill: parent
        radius: bar.hug ? 0 : Theme.radius
        color: Theme.bg
        border.color: Theme.border
        border.width: bar.hug ? 0 : 1

        // Each zone paints its modules in the order of Config.barLayout (changed by dragging or in Settings → Appearance)
        RowLayout {
            id: leftRow
            anchors { left: parent.left; leftMargin: bar.hug ? Theme.gap + 4 : 8; verticalCenter: parent.verticalCenter }
            spacing: 14
            Repeater { id: leftRep; model: Config.barLayout.left.map(k => ({ k })); delegate: modules }
        }

        RowLayout {
            id: centerRow
            anchors.centerIn: parent
            spacing: 14
            Repeater { id: centerRep; model: Config.barLayout.center.map(k => ({ k })); delegate: modules }
        }

        RowLayout {
            id: rightRow
            anchors { right: parent.right; rightMargin: bar.hug ? Theme.gap + 6 : 12; verticalCenter: parent.verticalCenter }
            spacing: 14
            Repeater { id: rightRep; model: Config.barLayout.right.map(k => ({ k })); delegate: modules }
        }

        // Copy of the module being dragged (the original stays dimmed)
        ShaderEffectSource {
            visible: bar.dragItem !== null
            sourceItem: bar.dragItem
            live: true
            width: bar.dragItem?.width ?? 0
            height: bar.dragItem?.height ?? 0
            x: bar.dragX - bar.grabDX
            y: bar.dragItem ? bar.dragItem.mapToItem(null, 0, 0).y : 0
            z: 2
        }
        // Slot where it will land
        Rectangle {
            visible: bar.drop !== null
            x: (bar.drop?.x ?? 0) - 1
            anchors.verticalCenter: parent.verticalCenter
            width: 2; height: parent.height * 0.6; radius: 1
            color: Theme.fg
            z: 1
        }
    }
}
