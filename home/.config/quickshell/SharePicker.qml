// Screen-share picker (Discord, browsers…): screens, windows or a region,
// with a live preview. Opened by ~/.local/bin/compartir-pantalla, which is the
// custom_picker_binary of xdg-desktop-portal-hyprland (~/.config/hypr/xdph.conf):
//   qs ipc call sharepicker open <fifo> <xdph window list> <true|false>
// (and `qs ipc call sharepicker cancel` closes it like Esc)
// The answer goes through the FIFO in the format xdph expects:
//   [SELECTION]<r>/screen:<monitor> | window:<id> | region:<monitor>@x,y,w,h
// An empty line means «cancel». Esc cancels, Enter shares, and so does a double click.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    property bool open: false
    property string fifo: ""
    property var windows: []           // [{ id, cls, title, addr }]
    property bool remember: false      // restore token: the app does not ask again
    property string tab: "screen"      // "screen" | "window" | "region"
    property string selScreen: ""
    property string selWindow: ""
    property var region: null          // { screen, x, y, w, h } relative to the monitor
    property bool selecting: false     // slurp running: the picker hides

    IpcHandler {
        target: "sharepicker"
        function open(fifo: string, list: string, token: bool): void {
            if (root.open) root.finish("")
            root.fifo = fifo
            root.windows = root.parseList(list)
            root.remember = token
            root.tab = "screen"
            root.selScreen = ShellState.focusedScreen?.name ?? ""
            root.selWindow = root.windows.length ? root.windows[0].id : ""
            root.region = null
            Hyprland.refreshToplevels()
            root.open = true
        }
        function cancel(): void { if (root.open) root.finish("") }
    }

    // "<id>[HC>]<class>[HT>]<title>[HE>]<address>[HA>]" repeated
    function parseList(list) {
        return list.split("[HA>]").filter(e => e.includes("[HC>]")).map(e => {
            const [id, rest1] = e.split("[HC>]")
            const [cls, rest2] = rest1.split("[HT>]")
            const [title, addr] = rest2.split("[HE>]")
            return { id: id, cls: cls, title: title, addr: addr }
        })
    }

    // Hyprland window (for the preview) from xdph's decimal address
    function toplevelFor(addr) {
        // (the QML engine has no BigInt; the addresses fit in 48 bits)
        const hex = Number(addr).toString(16)
        const t = Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "").replace(/^0+/, "").toLowerCase() === hex)
        return t?.wayland ?? null
    }

    function screenByName(name) { return Quickshell.screens.find(s => s.name === name) ?? null }

    readonly property bool canShare: tab === "screen" ? selScreen !== ""
                                   : tab === "window" ? selWindow !== ""
                                   : region !== null

    function share() {
        if (!canShare) return
        const flags = remember ? "r" : ""
        let sel
        if (tab === "screen") sel = "screen:" + selScreen
        else if (tab === "window") sel = "window:" + selWindow
        else sel = `region:${region.screen}@${region.x},${region.y},${region.w},${region.h}`
        finish("[SELECTION]" + flags + "/" + sel)
    }

    function finish(answer) {
        if (fifo !== "")
            Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" > "$2"', "sh", answer, fifo])
        fifo = ""
        open = false
        selecting = false
    }

    Process {
        id: slurp
        command: ["slurp", "-d", "-f", "%o %x %y %w %h"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ")
                const s = root.screenByName(p[0])
                if (p.length === 5 && s) {
                    root.region = { screen: p[0], x: +p[1] - s.x, y: +p[2] - s.y, w: +p[3], h: +p[4] }
                }
            }
        }
        onExited: root.selecting = false
    }
    function pickRegion() {
        selecting = true
        slurp.running = true
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: ShellState.focusedScreen
            visible: !root.selecting
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "#b3000000"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-sharepicker"

            MouseArea {
                anchors.fill: parent
                onClicked: root.finish("")
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: Math.min(960, win.width - 80)
                height: Math.min(580, win.height - 80)
                radius: Theme.radius * 1.5
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                // Clicks inside do not close it
                MouseArea { anchors.fill: parent }

                focus: true
                Keys.onEscapePressed: root.finish("")
                Keys.onReturnPressed: root.share()
                Keys.onEnterPressed: root.share()
                Keys.onTabPressed: {
                    const tabs = ["screen", "window", "region"]
                    root.tab = tabs[(tabs.indexOf(root.tab) + 1) % 3]
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 18

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        BarText { text: "󰍹"; font.pixelSize: 26 }
                        ColumnLayout {
                            spacing: 2
                            BarText { text: I18n.tr("Share screen"); font.pixelSize: 18; font.bold: true }
                            BarText { text: I18n.tr("Choose what the other app will see"); color: Theme.dim; font.pixelSize: 12 }
                        }
                        Item { Layout.fillWidth: true }

                        // Tabs
                        Rectangle {
                            implicitWidth: tabsRow.implicitWidth + 8
                            implicitHeight: 36
                            radius: 10
                            color: Theme.surface
                            border.color: Theme.border
                            Row {
                                id: tabsRow
                                anchors.centerIn: parent
                                spacing: 4
                                Repeater {
                                    model: [
                                        { v: "screen", icon: "󰍹", label: I18n.tr("Screens"), n: Quickshell.screens.length },
                                        { v: "window", icon: "󱂬", label: I18n.tr("Windows"), n: root.windows.length },
                                        { v: "region", icon: "󰩭", label: I18n.tr("Region"), n: -1 },
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool active: root.tab === modelData.v
                                        width: tabLabel.implicitWidth + 24; height: 28; radius: 7
                                        color: active ? Theme.accent : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        BarText {
                                            id: tabLabel
                                            anchors.centerIn: parent
                                            text: modelData.icon + "  " + modelData.label + (modelData.n >= 0 ? "  " + modelData.n : "")
                                            font.pixelSize: 12
                                            color: parent.active ? Theme.accentText : Theme.fg
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.tab = parent.modelData.v
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Content
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // ── Screens ──
                        RowLayout {
                            anchors.fill: parent
                            visible: root.tab === "screen"
                            spacing: 16
                            Repeater {
                                model: Quickshell.screens
                                delegate: SharePreview {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.maximumHeight: width * 0.62 + 56
                                    Layout.alignment: Qt.AlignVCenter
                                    source: modelData
                                    live: true
                                    selected: root.selScreen === modelData.name
                                    icon: modelData.name.startsWith("eDP") ? "󰌢" : "󰍹"
                                    title: modelData.name + (modelData === ShellState.focusedScreen ? "  ·  " + I18n.tr("active") : "")
                                    subtitle: `${Math.round(modelData.width * modelData.devicePixelRatio)}×${Math.round(modelData.height * modelData.devicePixelRatio)}`
                                    onPicked: root.selScreen = modelData.name
                                    onConfirmed: { root.selScreen = modelData.name; root.share() }
                                }
                            }
                        }

                        // ── Windows ──
                        GridView {
                            id: grid
                            anchors.fill: parent
                            visible: root.tab === "window"
                            clip: true
                            readonly property int cols: Math.max(2, Math.floor(width / 280))
                            cellWidth: Math.floor(width / cols)
                            cellHeight: cellWidth * 0.62 + 56 + 12
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.windows
                            delegate: Item {
                                required property var modelData
                                width: grid.cellWidth
                                height: grid.cellHeight
                                SharePreview {
                                    anchors.fill: parent
                                    anchors.rightMargin: 12
                                    anchors.bottomMargin: 12
                                    source: root.toplevelFor(modelData.addr)
                                    live: hovered || selected
                                    selected: root.selWindow === modelData.id
                                    appClass: modelData.cls
                                    title: modelData.title || modelData.cls
                                    subtitle: modelData.cls
                                    onPicked: root.selWindow = modelData.id
                                    onConfirmed: { root.selWindow = modelData.id; root.share() }
                                }
                            }

                            BarText {
                                anchors.centerIn: parent
                                visible: root.windows.length === 0
                                text: I18n.tr("No windows to share")
                                color: Theme.dim
                            }
                        }

                        // ── Region ──
                        ColumnLayout {
                            anchors.fill: parent
                            visible: root.tab === "region"
                            spacing: 14

                            Rectangle {
                                id: regionBox
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radius
                                color: Theme.surface
                                border.color: root.region ? Theme.accent : Theme.border
                                border.width: root.region ? 2 : 1
                                clip: true

                                // Preview: the whole monitor scaled and shifted to the region
                                Item {
                                    id: regionView
                                    visible: root.region !== null
                                    readonly property var scr: root.region ? root.screenByName(root.region.screen) : null
                                    readonly property real k: root.region
                                        ? Math.min((regionBox.width - 24) / root.region.w, (regionBox.height - 24) / root.region.h) : 1
                                    width: root.region ? root.region.w * k : 0
                                    height: root.region ? root.region.h * k : 0
                                    anchors.centerIn: parent
                                    clip: true
                                    ScreencopyView {
                                        captureSource: regionView.scr
                                        live: root.tab === "region" && root.region !== null
                                        x: root.region ? -root.region.x * regionView.k : 0
                                        y: root.region ? -root.region.y * regionView.k : 0
                                        width: regionView.scr ? regionView.scr.width * regionView.k : 0
                                        height: regionView.scr ? regionView.scr.height * regionView.k : 0
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    visible: root.region === null
                                    spacing: 10
                                    BarText { anchors.horizontalCenter: parent.horizontalCenter; text: "󰩭"; font.pixelSize: 48; color: Theme.dim }
                                    BarText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Drag to mark the area you want to share"); color: Theme.dim }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                BarText {
                                    Layout.fillWidth: true
                                    text: root.region
                                        ? `${root.region.screen}  ·  ` + I18n.tr("%1 at %2").arg(`${root.region.w}×${root.region.h}`).arg(`${root.region.x},${root.region.y}`)
                                        : I18n.tr("No region chosen")
                                    color: Theme.dim
                                    font.pixelSize: 12
                                }
                                ShareButton {
                                    text: root.region ? "󰩭  " + I18n.tr("Change region") : "󰩭  " + I18n.tr("Select region")
                                    onClicked: root.pickRegion()
                                }
                            }
                        }
                    }

                    // Footer
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Toggle {
                            checked: root.remember
                            onToggled: root.remember = !root.remember
                        }
                        ColumnLayout {
                            spacing: 1
                            BarText { text: I18n.tr("Remember this choice"); font.pixelSize: 12 }
                            BarText { text: I18n.tr("The app will not ask again"); color: Theme.dim; font.pixelSize: 11 }
                        }
                        Item { Layout.fillWidth: true }
                        ShareButton { text: I18n.tr("Cancel"); onClicked: root.finish("") }
                        ShareButton {
                            text: "󰄀  " + I18n.tr("Share")
                            primary: true
                            enabled: root.canShare
                            onClicked: root.share()
                        }
                    }
                }
            }
        }
    }
}
