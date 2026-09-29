// Settings → Personalization → QuickShell → Bar: preview with its three zones and the modules in
// their order (Config.barLayout). Click on a module: shows or hides it (the ones with an option in
// Config.barModules); ‹ › move it (Config.placeBarItem; they can also be dragged on the bar itself).
// Style (floating or attached) and clock. Saved in settings.json (Config.qml).
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Bar")
    subtitle: I18n.tr("Which modules show and where, style and clock")
    readonly property var o: Config.options
    readonly property var zones: [{ k: "left", label: I18n.tr("Left") }, { k: "center", label: I18n.tr("Centre") }, { k: "right", label: I18n.tr("Right") }]
    // hover of the chip arrows (the chip is already controlHi): one step lighter
    readonly property color arrowHover: Qt.tint(Theme.controlHi, Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.1))
    function mod(k) { return Config.barModules.find(m => m.k === k) ?? { k: k, label: k } }
    // Move one step: within its zone or, at the edge, to the next zone
    function step(k, dir) {
        const z = Config.barSections, lay = Config.barLayout
        const zi = z.findIndex(s => lay[s].includes(k)), i = lay[z[zi]].indexOf(k)
        if (dir < 0) {
            if (i > 0) Config.placeBarItem(k, z[zi], i - 1)
            else if (zi > 0) Config.placeBarItem(k, z[zi - 1], lay[z[zi - 1]].length)
        } else {
            if (i < lay[z[zi]].length - 1) Config.placeBarItem(k, z[zi], i + 2)
            else if (zi < z.length - 1) Config.placeBarItem(k, z[zi + 1], 0)
        }
    }

    // --- Preview ---
    SettingsGroup {
        label: I18n.tr("Modules")
        BarText {
            text: I18n.tr("Click a module to show or hide it; ‹ › to move it (or drag it on the bar itself)")
            color: Theme.dim; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        // The three zones, one per row, in the bar's order (left to right)
        Repeater {
            model: page.zones
            delegate: RowLayout {
                id: zone
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                BarText {
                    text: zone.modelData.label
                    color: Theme.dim; font.pixelSize: 11
                    Layout.preferredWidth: 72
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 7
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: flow.implicitHeight + 12
                    radius: 10
                    color: Theme.bg
                    border.color: Theme.border; border.width: 1
                    Flow {
                        id: flow
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                        spacing: 6
                        Repeater {
                            model: Config.barLayout[zone.modelData.k]
                            delegate: Rectangle {
                                id: chip
                                required property string modelData
                                readonly property var m: page.mod(modelData)
                                readonly property bool shown: !m.opt || page.o[m.opt]
                                // The arrows (MouseArea with hover) take the hover away from the chip's HoverHandler:
                                // the three of them are counted so it does not flicker
                                readonly property bool hot: chipHover.hovered || prev.hovered || next.hovered
                                width: chipRow.implicitWidth + 4; height: 28; radius: 8
                                color: !shown ? "transparent" : chip.hot ? Theme.controlHi : Theme.control
                                border.color: shown ? Theme.border : Theme.control; border.width: 1
                                HoverHandler { id: chipHover; cursorShape: chip.m.opt ? Qt.PointingHandCursor : Qt.ArrowCursor }
                                TapHandler { enabled: !!chip.m.opt; onTapped: page.o[chip.m.opt] = !page.o[chip.m.opt] }
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 0
                                    IconButton { id: prev; hoverColor: page.arrowHover; icon: "‹"; size: 20; opacity: chip.hot ? 1 : 0; onClicked: page.step(chip.modelData, -1) }
                                    BarText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: I18n.tr(chip.m.label)
                                        font.pixelSize: 11
                                        font.strikeout: !chip.shown
                                        color: chip.shown ? Theme.fg : Theme.dim
                                    }
                                    IconButton { id: next; hoverColor: page.arrowHover; icon: "›"; size: 20; opacity: chip.hot ? 1 : 0; onClicked: page.step(chip.modelData, 1) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("Style")
        SettingsRow {
            text: I18n.tr("Bar")
            description: I18n.tr("Floating with a margin, or attached to the top edge")
            ChoiceChips {
                value: o.barStyle
                options: [{ v: "float", label: I18n.tr("Floating") }, { v: "hug", label: I18n.tr("Attached") }]
                onChosen: v => o.barStyle = v
            }
        }
        SettingsRow {
            text: I18n.tr("Date on the clock")
            Toggle { checked: o.barDate; onToggled: o.barDate = !o.barDate }
        }
        SettingsRow {
            text: I18n.tr("Seconds")
            Toggle { checked: o.clockSeconds; onToggled: o.clockSeconds = !o.clockSeconds }
        }
    }

    Button {
        kind: "ghost"; icon: "󰜉"; text: I18n.tr("Reset the bar (style, modules, order and clock)")
        onClicked: Config.reset(Object.keys(Config.defaults).filter(k => k === "barStyle" || k === "barOrder" || k === "clockSeconds" || k.startsWith("bar")))
    }
}
