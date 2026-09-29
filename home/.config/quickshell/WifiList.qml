// List of Wi-Fi networks (NetworkService). Used by the bar panel and Settings.
// Click: connect. Open and saved ones, directly; new WPA ones ask for a password and
// 802.1X (eduroam) ones for user, password and method. If a saved one asks for data, the form shows.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property int maxItems: 10
    property bool showForget: false   // button to forget saved networks
    property string askSsid: ""
    spacing: 6

    // A saved network asked for credentials when connecting: its form opens
    Connections {
        target: NetworkService
        function onAskSsidChanged() { if (NetworkService.askSsid) root.askSsid = NetworkService.askSsid }
    }

    BarText {
        visible: !NetworkService.wifiOn || NetworkService.networks.length === 0
        text: NetworkService.wifiOn ? I18n.tr("Searching for networks…") : I18n.tr("Wi-Fi off")
        color: Theme.dim
    }
    BarText {
        visible: NetworkService.error !== ""
        text: NetworkService.error
        color: Theme.red
    }

    Repeater {
        model: NetworkService.wifiOn ? NetworkService.networks.slice(0, root.maxItems) : []

        delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property bool busy: NetworkService.busySsid === modelData.ssid
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 36
                radius: 8
                color: hover.hovered || row.modelData.active ? Theme.surface : "transparent"
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 10
                    BarText { text: NetworkService.signalIcon(row.modelData.signal) }
                    BarText {
                        Layout.fillWidth: true
                        text: row.modelData.ssid
                        elide: Text.ElideRight
                        font.bold: row.modelData.active
                    }
                    BarText {
                        text: row.busy ? I18n.tr("Connecting…") : row.modelData.active ? "󰄬" : row.modelData.secure ? "󰌾" : ""
                        color: Theme.dim
                        font.pixelSize: row.busy ? 11 : Theme.fontSize
                    }
                    IconButton { visible: root.showForget && row.modelData.known; danger: true; onClicked: NetworkService.forget(row.modelData) }
                }

                TapHandler {
                    onTapped: {
                        const n = row.modelData
                        if (NetworkService.busySsid) return
                        if (n.active) { if (root.showForget) NetworkService.disconnect(n); return }
                        if (n.type !== "open" && !n.known) root.askSsid = (root.askSsid === n.ssid ? "" : n.ssid)
                        else { root.askSsid = ""; NetworkService.connect(n, "") }
                    }
                }
            }

            // WPA personal: password
            WifiField {
                id: pass
                visible: root.askSsid === row.modelData.ssid && row.modelData.type === "psk"
                Layout.fillWidth: true
                password: true
                placeholder: I18n.tr("Password and Enter")
                onVisibleChanged: if (visible) { text = ""; focusInput() }
                onAccepted: if (text) { NetworkService.connect(row.modelData, text); root.askSsid = "" }
                onCancelled: root.askSsid = ""
            }

            // 802.1X (eduroam): user, password, method and advanced options
            ColumnLayout {
                id: eap
                visible: root.askSsid === row.modelData.ssid && row.modelData.type === "eap"
                Layout.fillWidth: true
                spacing: 6
                property string method: "peap"
                property bool advanced: false

                function send() {
                    if (!user.text || !secret.text) { (user.text ? secret : user).focusInput(); return }
                    NetworkService.connectEnterprise(row.modelData, user.text, secret.text, method,
                                                     anon.text, domain.text)
                    root.askSsid = ""
                }
                onVisibleChanged: if (visible) {
                    user.text = ""; secret.text = ""; anon.text = ""; domain.text = ""
                    method = "peap"; advanced = false; user.focusInput()
                }

                WifiField {
                    id: user
                    Layout.fillWidth: true
                    placeholder: I18n.tr("User (e.g. name@example.edu)")
                    onAccepted: secret.focusInput()
                    onCancelled: root.askSsid = ""
                    KeyNavigation.tab: secret.inputItem
                }
                WifiField {
                    id: secret
                    Layout.fillWidth: true
                    password: true
                    placeholder: I18n.tr("Password and Enter")
                    onAccepted: eap.send()
                    onCancelled: root.askSsid = ""
                }

                // Method: PEAP (MSCHAPv2) is the usual one on eduroam; TTLS (PAP) at some universities
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: [{ id: "peap", label: "PEAP" }, { id: "ttls", label: "TTLS" }]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool chosen: eap.method === modelData.id
                            implicitWidth: methodText.implicitWidth + 20
                            implicitHeight: 28
                            radius: 8
                            color: chosen ? Theme.sel : Theme.surface
                            BarText {
                                id: methodText
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.chosen ? Theme.selText : Theme.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: eap.method = parent.modelData.id
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    BarText {
                        text: eap.advanced ? I18n.tr("Fewer options") : I18n.tr("More options")
                        color: Theme.dim
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: eap.advanced = !eap.advanced
                        }
                    }
                }

                WifiField {
                    id: anon
                    visible: eap.advanced
                    Layout.fillWidth: true
                    placeholder: I18n.tr("Anonymous identity (optional)")
                    onAccepted: eap.send()
                    onCancelled: root.askSsid = ""
                }
                WifiField {
                    id: domain
                    visible: eap.advanced
                    Layout.fillWidth: true
                    placeholder: I18n.tr("Server domain (optional, e.g. example.edu)")
                    onAccepted: eap.send()
                    onCancelled: root.askSsid = ""
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 8
                    color: Theme.sel
                    BarText { anchors.centerIn: parent; text: I18n.tr("Connect"); color: Theme.selText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eap.send() }
                }
            }
        }
    }
}
