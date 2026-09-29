// Card of the screen-share picker: live preview (screen or window),
// icon and titles. Click picks (picked), double click shares (confirmed).
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: pc
    property var source: null
    property bool live: false
    property bool selected: false
    property string icon: ""
    property string appClass: ""
    property string title: ""
    property string subtitle: ""
    readonly property bool hovered: hover.hovered
    signal picked
    signal confirmed

    radius: Theme.radius
    color: selected || hovered ? Theme.surface : Theme.bg
    border.color: selected ? Theme.sel : hovered ? Theme.dim : Theme.border
    border.width: selected ? 2 : 1
    Behavior on border.color { ColorAnimation { duration: 120 } }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: pc.picked(); onDoubleTapped: pc.confirmed() }

    readonly property string iconPath: {
        if (!appClass) return ""
        const e = DesktopEntries.heuristicLookup(appClass)
        return Quickshell.iconPath(e?.icon ?? appClass.toLowerCase(), true)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Math.max(0, Theme.radius - 4)
            color: Theme.bg
            clip: true

            ScreencopyView {
                id: view
                captureSource: pc.source
                live: pc.live
                visible: hasContent
                // Keep the aspect ratio inside the slot
                readonly property real ar: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 16 / 10
                width: Math.min(parent.width - 2, (parent.height - 2) * ar)
                height: width / ar
                anchors.centerIn: parent
            }

            // No image (window on another workspace or minimized): large icon
            Column {
                anchors.centerIn: parent
                visible: !view.hasContent
                spacing: 6
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pc.iconPath !== ""
                    source: pc.iconPath
                    sourceSize: Qt.size(48, 48)
                    width: 48; height: 48
                }
                BarText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pc.iconPath === ""
                    text: pc.icon || "󰖯"
                    font.pixelSize: 40
                    color: Theme.dim
                }
            }

            // Chosen mark
            Rectangle {
                visible: pc.selected
                anchors { top: parent.top; right: parent.right; margins: 8 }
                width: 22; height: 22; radius: 11
                color: Theme.sel
                BarText { anchors.centerIn: parent; text: "󰄬"; color: Theme.selText; font.pixelSize: 14 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 10
            Image {
                visible: pc.iconPath !== ""
                source: pc.iconPath
                sourceSize: Qt.size(22, 22)
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
            }
            BarText {
                visible: pc.iconPath === ""
                text: pc.icon || "󰖯"
                font.pixelSize: 18
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                BarText {
                    Layout.fillWidth: true
                    text: pc.title
                    elide: Text.ElideRight
                    font.pixelSize: 12
                    font.bold: pc.selected
                }
                BarText {
                    Layout.fillWidth: true
                    visible: pc.subtitle !== "" && pc.subtitle !== pc.title
                    text: pc.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.dim
                }
            }
        }
    }
}
