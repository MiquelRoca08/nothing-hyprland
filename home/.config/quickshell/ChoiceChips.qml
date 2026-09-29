// Options as chips (one chosen, in red). options: [{ v, label, icon? }]; on click,
// chosen(v). For a single action use Button, not a one-option chip.
// Its natural width is all the chips in one row; if the space it gets is
// narrower (Layout.fillWidth or preferredWidth), they wrap to the next line. (A bare Flow,
// without a width, is measured with width 0 and stacks them one below the other.)
import QtQuick

Item {
    id: root
    property var options: []
    property var value
    property int spacing: 6
    signal chosen(var v)

    // Width of all of them in a row
    readonly property real naturalWidth: {
        let w = 0, n = 0
        for (const c of flow.children) if (c.width > 0 && c.visible) { w += c.width; n++ }
        return n ? w + spacing * (n - 1) : 0
    }
    implicitWidth: naturalWidth
    implicitHeight: flow.implicitHeight

    Flow {
        id: flow
        width: root.width > 0 ? root.width : root.naturalWidth
        spacing: root.spacing

        Repeater {
            model: root.options
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: root.value === modelData.v
                width: label.implicitWidth + 24; height: 30; radius: Theme.controlRadius
                color: selected ? (hover.hovered ? Theme.selHi : Theme.sel) : hover.hovered ? Theme.controlHi : Theme.control
                border.color: Theme.border
                border.width: selected ? 0 : 1
                Behavior on color { ColorAnimation { duration: 100 } }
                BarText {
                    id: label
                    anchors.centerIn: parent
                    text: (chip.modelData.icon ? chip.modelData.icon + "  " : "") + chip.modelData.label
                    font.pixelSize: 12
                    color: chip.selected ? Theme.selText : hover.hovered ? Theme.fg : Theme.fgSoft
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.chosen(chip.modelData.v) }
            }
        }
    }
}
