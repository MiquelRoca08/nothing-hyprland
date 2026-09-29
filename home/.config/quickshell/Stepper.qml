// Pick a value from a list with arrows: ‹ value ›. items: texts; index: the chosen one.
// On change, moved(i). Meant for long lists (resolutions, refresh rates, scales).
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property var items: []
    property int index: 0
    signal moved(int i)
    spacing: 8

    component Arrow: BarText {
        property int step
        text: step < 0 ? "󰅁" : "󰅂"
        color: enabledArrow ? Theme.fg : Theme.border
        readonly property bool enabledArrow: root.index + step >= 0 && root.index + step < root.items.length
        MouseArea {
            anchors.fill: parent; anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: if (parent.enabledArrow) root.moved(root.index + parent.step)
        }
    }

    Arrow { step: -1 }
    BarText {
        Layout.minimumWidth: 130
        horizontalAlignment: Text.AlignHCenter
        text: root.items[root.index] ?? "—"
    }
    Arrow { step: 1 }
}
