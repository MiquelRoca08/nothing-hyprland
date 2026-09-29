// Settings → Wi-Fi: turn on/off, scan, connect, disconnect and forget networks, and the DNS of the
// current connection (Wi-Fi or cable): the router's, Cloudflare, Google, Quad9 or a custom one
// (NetworkService.setDns; also for every saved network).
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: "Wi-Fi"
    subtitle: I18n.tr("Available and saved networks, and DNS")
    Component.onCompleted: { NetworkService.reload(); NetworkService.dnsLoad() }
    // Option chosen in the chips: follows the connection's, except while typing a custom one
    property string dnsChoice: NetworkService.dnsMode
    Connections {
        target: NetworkService
        function onDnsModeChanged() { page.dnsChoice = NetworkService.dnsMode }
    }
    readonly property var dnsParsed: NetworkService.dnsParse(dnsField.text)
    function dnsTarget() {
        return page.dnsChoice === "auto" ? null
             : page.dnsChoice === "custom" ? page.dnsParsed
             : NetworkService.dnsPresets[page.dnsChoice]
    }
    Timer { interval: 8000; running: true; repeat: true; onTriggered: NetworkService.reload() }

    SettingsGroup {
        SettingsRow {
            text: "Wi-Fi"
            description: NetworkService.kind === "wifi" ? I18n.tr("Connected to %1").arg(NetworkService.name)
                       : NetworkService.kind === "ethernet" ? I18n.tr("Connected by cable") : I18n.tr("Not connected")
            Toggle { checked: NetworkService.wifiOn; onToggled: NetworkService.setWifi(!NetworkService.wifiOn) }
        }
    }

    SettingsGroup {
        label: I18n.tr("Available networks")
        visible: NetworkService.wifiOn
        RowLayout {
            Layout.fillWidth: true
            BarText { text: I18n.tr("Click to connect · click the connected one to disconnect"); color: Theme.dim; font.pixelSize: 11; Layout.fillWidth: true }
            Button {
                icon: "󰑐"; text: I18n.tr("Scan")
                busy: NetworkService.scanning
                onClicked: NetworkService.rescan()
            }
        }
        WifiList { Layout.fillWidth: true; maxItems: 20; showForget: true }
    }

    SettingsGroup {
        label: "DNS"
        visible: NetworkService.kind !== ""
        SettingsRow {
            text: I18n.tr("DNS server")
            description: I18n.tr("For the current connection (%1). In use: ").arg(NetworkService.name)
                       + (NetworkService.dnsInUse.length ? NetworkService.dnsInUse.join(", ") : "—")
            BarText { visible: NetworkService.dnsBusy; text: I18n.tr("Applying…"); color: Theme.dim }
        }
        ChoiceChips {
            Layout.fillWidth: true
            value: page.dnsChoice
            options: [
                { v: "auto", label: I18n.tr("Automatic (router)") },
                { v: "cloudflare", label: "Cloudflare · 1.1.1.1" },
                { v: "google", label: "Google · 8.8.8.8" },
                { v: "quad9", label: "Quad9 · 9.9.9.9" },
                { v: "custom", label: I18n.tr("Custom") },
            ]
            onChosen: v => {
                page.dnsChoice = v
                if (v === "custom") {
                    if (!dnsField.text) dnsField.text = NetworkService.dnsServers.join(" ")
                    dnsField.focusInput()
                } else if (v !== NetworkService.dnsMode) NetworkService.setDns(page.dnsTarget(), false)
            }
        }
        RowLayout {
            visible: page.dnsChoice === "custom"
            Layout.fillWidth: true
            spacing: 8
            WifiField {
                id: dnsField
                Layout.fillWidth: true
                placeholder: I18n.tr("IPv4 or IPv6 addresses separated by spaces (e.g. 1.1.1.1 9.9.9.9)")
                onAccepted: if (page.dnsParsed) NetworkService.setDns(page.dnsParsed, false)
                onCancelled: page.dnsChoice = NetworkService.dnsMode
            }
            Button {
                kind: "primary"; text: I18n.tr("Apply")
                enabled: !!page.dnsParsed
                busy: NetworkService.dnsBusy
                onClicked: NetworkService.setDns(page.dnsParsed, false)
            }
        }
        BarText {
            visible: page.dnsChoice === "custom" && dnsField.text !== "" && !page.dnsParsed
            text: I18n.tr("Some address is not valid")
            color: Theme.red
            font.pixelSize: 11
        }
        BarText {
            visible: NetworkService.dnsError !== ""
            text: NetworkService.dnsError
            color: Theme.red
            font.pixelSize: 11
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            BarText {
                Layout.fillWidth: true
                text: I18n.tr("Applied without disconnecting. The other saved networks keep their DNS")
                color: Theme.dim
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
            Button {
                kind: "ghost"; icon: "󰑓"; text: I18n.tr("Apply to every saved network")
                enabled: page.dnsChoice !== "custom" || !!page.dnsParsed
                onClicked: NetworkService.setDns(page.dnsTarget(), true)
            }
        }
    }
}
