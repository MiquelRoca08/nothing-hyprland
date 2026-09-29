pragma Singleton
// Network (NetworkManager through nmcli). Single source for the bar, the Wi-Fi panel
// and Settings. State every 5 s; network list on demand (reload()).
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Current connection
    property string kind: ""           // "wifi" | "ethernet" | ""
    property string name: ""
    property int signal: 0

    // Wi-Fi
    property bool wifiOn: true
    // type: "open" (no password), "psk" (WPA/WPA3 personal) or "eap" (enterprise 802.1X,
    // e.g. eduroam: user + password)
    property var networks: []          // [{ ssid, signal, secure, type, active, known }]
    property string busySsid: ""       // connecting to…
    property string error: ""
    property string askSsid: ""        // saved network that asked for credentials: WifiList opens the form
    readonly property bool scanning: rescanProc.running

    // DNS of the current connection (Settings → Wi-Fi). dnsMode: "auto" (the router's, via DHCP), a
    // dnsPresets key or "custom"; dnsServers: the ones set on the connection; dnsInUse: the ones
    // really in use now (the router's if automatic)
    readonly property var dnsPresets: ({
        cloudflare: { label: "Cloudflare", v4: ["1.1.1.1", "1.0.0.1"], v6: ["2606:4700:4700::1111", "2606:4700:4700::1001"] },
        google:     { label: "Google",     v4: ["8.8.8.8", "8.8.4.4"], v6: ["2001:4860:4860::8888", "2001:4860:4860::8844"] },
        quad9:      { label: "Quad9",      v4: ["9.9.9.9", "149.112.112.112"], v6: ["2620:fe::fe", "2620:fe::9"] },
    })
    property string dnsMode: "auto"
    property var dnsServers: []
    property var dnsInUse: []
    property string dnsError: ""
    readonly property bool dnsBusy: dnsSetProc.running

    function dnsLoad() { if (name) { dnsGetProc.command = dnsGetCmd(); dnsGetProc.running = true } }
    // Splits a hand-written list into IPv4 and IPv6; null if something is not a valid address
    function dnsParse(text) {
        const v4 = [], v6 = []
        for (const a of text.split(/[\s,;]+/).filter(x => x)) {
            if (/^(25[0-5]|2[0-4]\d|1?\d?\d)(\.(25[0-5]|2[0-4]\d|1?\d?\d)){3}$/.test(a)) v4.push(a)
            else if (/^[0-9a-fA-F:]+$/.test(a) && a.includes(":")) v6.push(a)
            else return null
        }
        return v4.length || v6.length ? { v4: v4, v6: v6 } : null
    }
    // Sets the DNS (servers = { v4, v6 }, or null to go back to the router's) on the current
    // connection or, with all, on every saved Wi-Fi and wired one. Applied without disconnecting
    // (device reapply; if that is not possible, the connection is reactivated).
    function setDns(servers, all) {
        dnsError = ""
        const auto = !servers
        dnsSetProc.command = ["sh", "-c",
            'v4=$1; v6=$2; ign=$3; cur=$4; shift 4; ' +
            // If the connection does not support IPv6 DNS (IPv6 disabled), only the IPv4 ones
            'for c in "$@"; do nmcli connection modify id "$c" ipv4.dns "$v4" ipv4.ignore-auto-dns "$ign" ' +
            'ipv6.dns "$v6" ipv6.ignore-auto-dns "$ign" 2>/dev/null || ' +
            'nmcli connection modify id "$c" ipv4.dns "$v4" ipv4.ignore-auto-dns "$ign" || exit 1; done; ' +
            'dev=$(nmcli -g GENERAL.DEVICES connection show id "$cur" 2>/dev/null); ' +
            '[ -n "$dev" ] && { nmcli device reapply "$dev" >/dev/null 2>&1 || nmcli connection up id "$cur" >/dev/null; }; exit 0',
            "sh", auto ? "" : servers.v4.join(" "), auto ? "" : servers.v6.join(" "), auto ? "no" : "yes", name]
        if (all) {
            dnsAllProc.pending = dnsSetProc.command
            dnsAllProc.running = true
        } else {
            dnsSetProc.command = dnsSetProc.command.concat([name])
            dnsSetProc.running = true
        }
    }
    function dnsGetCmd() {
        return ["sh", "-c",
            'c=$1; nmcli -t --escape no -f ipv4.dns,ipv6.dns,ipv4.ignore-auto-dns connection show id "$c"; ' +
            'dev=$(nmcli -g GENERAL.DEVICES connection show id "$c"); ' +
            'nmcli -t --escape no -f IP4.DNS,IP6.DNS device show "$dev" 2>/dev/null',
            "sh", name]
    }

    function signalIcon(s) { return ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(s / 20))] }

    function refresh() { statusProc.running = true }
    function reload() { listProc.running = true }
    function rescan() { rescanProc.running = true }
    function setWifi(on) {
        wifiOn = on
        radioProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        radioProc.running = true
    }
    // Open and WPA personal networks (empty password = open or already saved)
    function connect(net, password) {
        error = ""
        askSsid = ""
        busySsid = net.ssid
        connectProc.command = net.known && !password
            ? ["nmcli", "connection", "up", "id", net.ssid]
            : ["sh", "-c",
               // If the saved one had a different password, the profile is rebuilt
               'ssid=$1; shift; nmcli connection delete id "$ssid" >/dev/null 2>&1; nmcli device wifi connect "$ssid" "$@"',
               "sh", net.ssid].concat(password ? ["password", password] : [])
        connectProc.running = true
    }

    // 802.1X networks (eduroam): creates the profile with user and password and activates it. If it does not connect,
    // it deletes it so no half-made one is left. method: "peap" (phase 2 MSCHAPv2) or "ttls" (phase 2 PAP).
    // With domain, it validates the server certificate with the system CAs (avoids fake networks).
    function connectEnterprise(net, identity, password, method, anonymous, domain) {
        error = ""
        askSsid = ""
        busySsid = net.ssid
        let args = ["type", "wifi", "con-name", net.ssid, "ssid", net.ssid,
                    "wifi-sec.key-mgmt", "wpa-eap",
                    "802-1x.eap", method, "802-1x.phase2-auth", method === "ttls" ? "pap" : "mschapv2",
                    "802-1x.identity", identity, "802-1x.password", password]
        if (anonymous) args = args.concat(["802-1x.anonymous-identity", anonymous])
        if (domain) args = args.concat(["802-1x.ca-cert", "/etc/ssl/certs/ca-certificates.crt",
                                        "802-1x.domain-suffix-match", domain])
        connectProc.command = ["sh", "-c",
            'ssid=$1; shift; nmcli connection delete id "$ssid" >/dev/null 2>&1; ' +
            'nmcli connection add "$@" >/dev/null && nmcli connection up id "$ssid" && exit 0; ' +
            'e=$?; nmcli connection delete id "$ssid" >/dev/null 2>&1; exit $e',
            "sh", net.ssid].concat(args)
        connectProc.running = true
    }
    function disconnect(net) { Quickshell.execDetached(["nmcli", "connection", "down", "id", net.ssid]); later.restart() }
    function forget(net) { Quickshell.execDetached(["nmcli", "connection", "delete", "id", net.ssid]); later.restart() }

    Process {
        id: statusProc
        command: ["sh", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION dev | grep -E '^(wifi|ethernet):connected:' | head -1; " +
            "echo '--'; nmcli -t -f IN-USE,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^\\*' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [dev, wifi] = text.split("--\n")
                const d = dev.trim().split(":")
                root.kind = d.length >= 3 ? d[0] : ""
                root.name = d.length >= 3 ? d.slice(2).join(":") : ""
                const w = (wifi ?? "").trim().split(":")
                root.signal = w.length >= 2 ? parseInt(w[1]) || 0 : 0
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    Process {
        id: listProc
        command: ["sh", "-c",
            "nmcli radio wifi; echo '--'; " +
            "nmcli -t -f NAME,TYPE connection show | grep ':802-11-wireless$' | sed 's/:802-11-wireless$//'; echo '--'; " +
            "nmcli -t --escape no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [radio, saved, list] = text.split("--\n")
                root.wifiOn = radio.trim() === "enabled"
                const known = new Set(saved.split("\n").filter(s => s))
                const seen = {}
                for (const line of (list ?? "").split("\n")) {
                    const p = line.split(":")
                    if (p.length < 4) continue
                    const ssid = p.slice(3).join(":")
                    if (!ssid) continue
                    const sec = p[2] === "--" ? "" : p[2]
                    // OWE = open with encryption: asks for nothing either
                    const type = sec.includes("802.1X") ? "eap" : (sec === "" || sec === "OWE") ? "open" : "psk"
                    const net = { ssid, signal: parseInt(p[1]) || 0, secure: type !== "open", type,
                                  active: p[0] === "*", known: known.has(ssid) }
                    if (!seen[ssid] || net.active || net.signal > seen[ssid].signal) seen[ssid] = net
                }
                root.networks = Object.values(seen).sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
            }
        }
    }

    Process {
        id: connectProc
        stderr: StdioCollector { id: connectErr }
        onExited: code => {
            if (code !== 0) {
                const secrets = /Secrets were required|password|802-1x|secrets/i.test(connectErr.text)
                root.error = secrets ? I18n.tr("Wrong or missing details") : I18n.tr("Could not connect")
                // Asks for the data again (also if it was a saved network)
                if (secrets) root.askSsid = root.busySsid
                // A failed attempt leaves the card without network: go back to the best saved network
                Quickshell.execDetached(["sh", "-c",
                    "dev=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == \"wifi\" { print $1; exit }'); " +
                    "[ -n \"$dev\" ] && nmcli device connect \"$dev\""])
            }
            root.busySsid = ""
            root.reload(); root.refresh()
        }
    }
    Process {
        id: dnsGetProc
        stdout: StdioCollector {
            onStreamFinished: {
                // «field:value» lines: ipv4.dns, ipv6.dns (comma lists), ipv4.ignore-auto-dns
                // and the device's IP4.DNS[n] / IP6.DNS[n] (the ones in use now)
                let v4 = [], v6 = [], ign = false
                const use = []
                const list = v => v.split(",").map(x => x.trim()).filter(x => x)
                for (const line of text.split("\n")) {
                    const i = line.indexOf(":")
                    if (i < 0) continue
                    const k = line.slice(0, i), v = line.slice(i + 1).trim()
                    if (k === "ipv4.dns") v4 = list(v)
                    else if (k === "ipv6.dns") v6 = list(v)
                    else if (k === "ipv4.ignore-auto-dns") ign = v === "yes"
                    else if (/^IP[46]\.DNS/.test(k) && v) use.push(v)
                }
                root.dnsServers = v4.concat(v6)
                root.dnsInUse = use
                const presetKey = Object.keys(root.dnsPresets).find(k => root.dnsPresets[k].v4[0] === v4[0] && v4.length > 0)
                root.dnsMode = !ign && v4.length === 0 && v6.length === 0 ? "auto" : presetKey ?? "custom"
            }
        }
    }
    Process {
        id: dnsSetProc
        stderr: StdioCollector { id: dnsErr }
        onExited: code => {
            if (code !== 0) root.dnsError = dnsErr.text.trim().split("\n").pop() || I18n.tr("Could not change the DNS")
            dnsLater.restart()
        }
    }
    // Every saved one: first the list of Wi-Fi and wired connections, then dnsSetProc
    Process {
        id: dnsAllProc
        property var pending: []
        command: ["sh", "-c", "nmcli -t --escape no -f NAME,TYPE connection show | " +
                  "awk -F: '$NF ~ /wireless|ethernet/ { sub(/:[^:]*$/, \"\"); print }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(x => x)
                dnsSetProc.command = dnsAllProc.pending.concat(names)
                dnsSetProc.running = true
            }
        }
    }
    Timer { id: dnsLater; interval: 1500; onTriggered: root.dnsLoad() }
    onNameChanged: dnsLoad()
    Process { id: radioProc; onExited: { root.reload(); root.refresh() } }
    Process { id: rescanProc; command: ["nmcli", "device", "wifi", "rescan"]; onExited: root.reload() }
    Timer { id: later; interval: 1500; onTriggered: { root.reload(); root.refresh() } }
}
