// Settings window: sidebar with the categories of Config.settingsTree as collapsible
// groups (one open at a time: the current page's) and scrollable content.
// Open: SUPER+I, the bar's 󰒓 button or `qs ipc call settings toggle` (opens on Home);
// `qs ipc call settings open wifi` opens a specific page.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    IpcHandler {
        target: "settings"
        function toggle(): void { ShellState.settingsOpen = !ShellState.settingsOpen }
        function open(page: string): void { ShellState.openSettings(page) }
        // Something changed outside (a Terminal.run command finished): pages reload
        function changed(): void { ShellState.settingsChanged() }
    }

    LazyLoader {
        active: ShellState.settingsOpen

        FloatingWindow {
            id: win
            title: "Ajustes"
            implicitWidth: 1140
            implicitHeight: 780
            color: Theme.bg
            visible: true
            onClosed: ShellState.settingsOpen = false
            onVisibleChanged: if (!visible) ShellState.settingsOpen = false

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: ShellState.settingsOpen = false
            }


            RowLayout {
                anchors.fill: parent
                spacing: 0
                // Click outside a text field (on a button or on the sidebar): drops its
                // focus. Fields keep their own click, so clicking on one does not deselect it. Inside
                // the content another one is needed (below): the Flickable takes the click first
                TapHandler { onTapped: keys.forceActiveFocus() }

                // Sidebar
                Rectangle {
                    id: side
                    Layout.fillHeight: true
                    Layout.preferredWidth: 236
                    color: Theme.bgAlt

                    // Expanded categories: when the page changes, the ones that contain it
                    property var expanded: Config.settingsEntry(ShellState.settingsPage).parents
                    Connections {
                        target: ShellState
                        function onSettingsPageChanged() { side.expanded = Config.settingsEntry(ShellState.settingsPage).parents }
                    }
                    // Clicking a category: if it is expanded it collapses; otherwise, go to its first page
                    function pick(e) {
                        if (!e.children) { ShellState.settingsPage = e.k; return }
                        if (expanded.includes(e.k)) { expanded = expanded.filter(k => k !== e.k); return }
                        const leaf = Config.settingsEntry(e.k)
                        ShellState.settingsPage = leaf.k
                        expanded = leaf.parents
                    }
                    readonly property var rows: Config.settingsFlat.filter(e => e.parents.every(k => expanded.includes(k)))

                    ColumnLayout {
                        anchors { fill: parent; margins: 14 }
                        spacing: 4

                        BarText {
                            text: I18n.tr("SETTINGS")
                            font.family: Theme.displayFont
                            font.pixelSize: 26
                            font.weight: Font.Black
                            Layout.bottomMargin: 14
                            Layout.leftMargin: 6
                        }

                        Flickable {
                            id: sideFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentHeight: rowsCol.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds
                            FastWheel { flick: sideFlick }
                            // parent: the Flickable itself, not its content (so it does not scroll with it)
                            ScrollBar { parent: sideFlick; flick: sideFlick; anchors { right: parent.right; top: parent.top; bottom: parent.bottom } }

                            ColumnLayout {
                                id: rowsCol
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: side.rows
                                    delegate: Rectangle {
                                        id: row
                                        required property var modelData
                                        required property int index
                                        readonly property bool group: !!modelData.children
                                        readonly property bool selected: ShellState.settingsPage === modelData.k
                                        readonly property bool open: group && side.expanded.includes(modelData.k)
                                        // Category containing the current page
                                        readonly property bool current: group && Config.settingsEntry(ShellState.settingsPage).parents.includes(modelData.k)
                                        Layout.fillWidth: true
                                        Layout.topMargin: modelData.depth === 0 && row.index > 0 ? 4 : 0
                                        implicitHeight: modelData.depth === 0 ? 36 : 32
                                        radius: 10
                                        color: selected ? Theme.selSoft : hover.hovered ? Theme.surface : "transparent"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                        // Red mark of the current page
                                        Rectangle {
                                            visible: row.selected
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                            width: 3; height: parent.height - 14; radius: 2
                                            color: Theme.sel
                                        }
                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 12 + row.modelData.depth * 16; rightMargin: 10 }
                                            spacing: 12
                                            BarText {
                                                text: row.modelData.icon
                                                font.pixelSize: row.modelData.depth === 0 ? 16 : 14
                                                color: row.selected || row.current ? Theme.sel : row.modelData.depth === 0 ? Theme.fgSoft : Theme.dim
                                            }
                                            BarText {
                                                text: I18n.tr(row.modelData.label)
                                                font.pixelSize: row.modelData.depth === 0 ? 14 : 13
                                                font.bold: row.current || row.selected
                                                color: row.selected || row.current || hover.hovered ? Theme.fg : row.modelData.depth === 0 ? Theme.fgSoft : Theme.dim
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            BarText {
                                                visible: row.group
                                                text: row.open ? "󰅀" : "󰅂"
                                                font.pixelSize: 12
                                                color: Theme.dim
                                            }
                                        }
                                        TapHandler { onTapped: side.pick(row.modelData) }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.border }

                // Content
                Flickable {
                    id: content
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: pageLoader.implicitHeight + 56
                    boundsBehavior: Flickable.StopAtBounds
                    // Wheel and touchpad faster than Qt's, and a bar for long lists
                    FastWheel { flick: content }
                    // Click on an empty area of the page: drops the text field's focus
                    TapHandler { onTapped: keys.forceActiveFocus() }
                    ScrollBar {
                        parent: content; flick: content
                        anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 6; bottom: parent.bottom; bottomMargin: 6 }
                        z: 10
                    }

                    Loader {
                        id: pageLoader
                        x: 32; y: 28
                        width: parent.width - 64
                        source: Config.settingsEntry(ShellState.settingsPage).file ?? "SettingsSoon.qml"
                        onSourceChanged: content.contentY = 0
                    }
                }
            }
        }
    }
}
