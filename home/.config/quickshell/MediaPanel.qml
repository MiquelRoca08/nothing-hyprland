// Player panel below the bar's title: cover art, track, progress
// (click or drag to seek), controls and, if several apps are playing or
// open (Spotify, Firefox…), the list to pick which one to control.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property Item anchorItem
    property bool open: false
    readonly property var player: MediaService.player

    // The MPRIS position does not notify by itself: it is refreshed every second while the panel is open
    Timer {
        interval: 1000
        running: root.open && (root.player?.isPlaying ?? false)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.player?.positionChanged()
    }
    // No players, nothing to show
    onPlayerChanged: if (!player) open = false

    component Button: BarText {
        property bool active: true
        property bool highlighted: false
        signal clicked
        color: !active ? Theme.border : highlighted ? Theme.fg : Theme.dim
        font.pixelSize: 18
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            enabled: parent.active
            onClicked: parent.clicked()
        }
    }

    LazyLoader {
        active: root.open && root.player !== null

        PopupWindow {
            id: popup
            visible: true
            anchor {
                item: root.anchorItem
                edges: Edges.Bottom
                gravity: Edges.Bottom
                adjustment: PopupAdjustment.SlideX
                // The icon is centred on the bar: the panel starts right below it
                rect.y: (Theme.barHeight + root.anchorItem.height) / 2
            }
            implicitWidth: 360
            implicitHeight: body.implicitHeight + 28
            color: "transparent"

            HyprlandFocusGrab {
                active: true
                windows: [popup]
                onCleared: root.open = false
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cardRadius
                color: Theme.bg
                border.color: Theme.border
                border.width: 1

                ColumnLayout {
                    id: body
                    readonly property var p: root.player
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 12

                    // Cover art + track
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        ClippingRectangle {
                            implicitWidth: 84
                            implicitHeight: 84
                            radius: Theme.cardRadius - 4
                            color: Theme.surface
                            BarText {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                text: "󰎆"
                                font.pixelSize: 32
                                color: Theme.dim
                            }
                            Image {
                                id: art
                                anchors.fill: parent
                                source: body.p?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(168, 168)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            BarText {
                                Layout.fillWidth: true
                                text: MediaService.appName(body.p).toUpperCase()
                                color: Theme.dim
                                font.pixelSize: 10
                                font.letterSpacing: 1
                                elide: Text.ElideRight
                            }
                            BarText {
                                Layout.fillWidth: true
                                text: body.p?.trackTitle || I18n.tr("Untitled")
                                font.bold: true
                                font.pixelSize: 14
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            BarText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: body.p?.trackArtist ?? ""
                                elide: Text.ElideRight
                            }
                            BarText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: body.p?.trackAlbum ?? ""
                                color: Theme.dim
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Progress
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (body.p?.lengthSupported ?? false) && body.p.length > 0
                        spacing: 2
                        Slider {
                            Layout.fillWidth: true
                            from: 0
                            to: body.p?.length ?? 1
                            value: body.p?.position ?? 0
                            enabled: body.p?.canSeek ?? false
                            onMoved: v => { if (body.p?.canSeek) body.p.position = v }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            BarText {
                                text: MediaService.formatTime(body.p?.position ?? 0)
                                color: Theme.dim; font.pixelSize: 11
                                Layout.fillWidth: true
                            }
                            BarText {
                                text: MediaService.formatTime(body.p?.length ?? 0)
                                color: Theme.dim; font.pixelSize: 11
                            }
                        }
                    }

                    // Controls
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 26
                        Button {
                            text: "󰒝"
                            font.pixelSize: 15
                            active: body.p?.shuffleSupported ?? false
                            highlighted: body.p?.shuffle ?? false
                            onClicked: body.p.shuffle = !body.p.shuffle
                        }
                        Button {
                            text: "󰒮"
                            highlighted: true
                            active: body.p?.canGoPrevious ?? false
                            onClicked: body.p.previous()
                        }
                        Button {
                            text: body.p?.isPlaying ? "󰏤" : "󰐊"
                            font.pixelSize: 26
                            highlighted: true
                            active: body.p?.canTogglePlaying ?? false
                            onClicked: body.p.togglePlaying()
                        }
                        Button {
                            text: "󰒭"
                            highlighted: true
                            active: body.p?.canGoNext ?? false
                            onClicked: body.p.next()
                        }
                        Button {
                            text: body.p?.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                            font.pixelSize: 15
                            active: body.p?.loopSupported ?? false
                            highlighted: (body.p?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                            // No repeat → playlist → track → no repeat
                            onClicked: body.p.loopState = body.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                                : body.p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                                : MprisLoopState.None
                        }
                    }

                    // Sources (only if there is more than one)
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: MediaService.players.length > 1
                        spacing: 4

                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
                        BarText {
                            text: I18n.tr("SOURCES")
                            color: Theme.dim
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            Layout.topMargin: 4
                        }

                        Repeater {
                            model: MediaService.players
                            delegate: Rectangle {
                                id: row
                                required property var modelData
                                readonly property bool selected: modelData === body.p
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: 8
                                color: selected || hover.hovered ? Theme.surface : "transparent"
                                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: MediaService.choose(row.modelData) }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    spacing: 10
                                    BarText {
                                        text: row.selected ? "󰄯" : "󰄰"
                                        color: row.selected ? Theme.fg : Theme.dim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        BarText {
                                            Layout.fillWidth: true
                                            text: MediaService.appName(row.modelData)
                                            elide: Text.ElideRight
                                        }
                                        BarText {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: row.modelData.trackTitle ?? ""
                                            color: Theme.dim
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                    BarText {
                                        text: row.modelData.isPlaying ? "󰐊" : "󰏤"
                                        color: row.modelData.isPlaying ? Theme.fg : Theme.dim
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
