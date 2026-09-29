// Button of the screen-share picker (primary: filled white).
import QtQuick

Rectangle {
    id: btn
    property string text: ""
    property bool primary: false
    signal clicked
    implicitWidth: lbl.implicitWidth + 32
    implicitHeight: 34
    radius: 9
    opacity: !enabled ? 0.4 : primary && bh.hovered ? 0.85 : 1
    color: primary ? Theme.accent : bh.hovered ? Theme.surface : Theme.bg
    border.color: Theme.border
    border.width: primary ? 0 : 1
    HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (btn.enabled) btn.clicked() }
    BarText {
        id: lbl
        anchors.centerIn: parent
        text: btn.text
        font.pixelSize: 12
        font.bold: btn.primary
        color: btn.primary ? Theme.accentText : Theme.fg
    }
}
