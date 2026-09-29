// List of audio devices (outputs or inputs) to pick the default one.
// Used by Settings → Sound and the bar's sound panel.
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list
    property var nodes: []
    property var current
    property bool isOutput: true
    property color highlight: Theme.control // background of the chosen one (over the surface card)
    Layout.fillWidth: true
    spacing: 4

    Repeater {
        model: list.nodes
        delegate: Rectangle {
            required property var modelData
            readonly property bool selected: modelData === list.current
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 8
            color: selected || hover.hovered ? list.highlight : "transparent"
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10
                BarText { text: selected ? "󰄯" : "󰄰"; color: selected ? Theme.fg : Theme.dim }
                BarText {
                    Layout.fillWidth: true
                    text: modelData.description || modelData.nickname || modelData.name
                    elide: Text.ElideRight
                }
            }
            TapHandler {
                onTapped: {
                    if (list.isOutput) Pipewire.preferredDefaultAudioSink = modelData
                    else Pipewire.preferredDefaultAudioSource = modelData
                }
            }
        }
    }
}
