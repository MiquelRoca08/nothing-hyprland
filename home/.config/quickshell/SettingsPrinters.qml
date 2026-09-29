// Settings → Connections → Printers (CUPS): if CUPS is missing, a button installs and enables it (with
// avahi, to find printers on the network). Configured printers with their state,
// default (the user's, lpoptions), test page, resume if paused and remove;
// the queue with «Cancel»; and add: search the network and USB (lpinfo) or by address, without
// drivers (IPP Everywhere, lpadmin -m everywhere). What needs sudo goes to the terminal.
// Data from scripts/impresoras.sh; the state refreshes every 5 s while the page is open.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Printers")
    subtitle: I18n.tr("Configured ones, print queue and adding new ones")

    readonly property string script: Quickshell.shellPath("scripts/impresoras.sh")
    property bool installed: true
    property bool active: true
    property bool ghostscript: true // CUPS filters need it: without it, nothing prints
    property bool loaded: false
    property var printers: []       // [{ name, state, isDefault, uri, detail }]
    property var jobs: []           // [{ id, printer, user, bytes, date }]
    property var found: []          // [{ kind, uri, name, desc }]
    property bool searched: false
    property bool avahi: true       // without avahi-daemon no network printer shows up
    property string confirm: ""
    property string message: ""
    readonly property var stateNames: ({ idle: I18n.tr("Ready"), printing: I18n.tr("Printing"), disabled: I18n.tr("Paused") })
    readonly property var jobStates: ({ queued: I18n.tr("Queued"), printing: I18n.tr("Printing"), stopped: I18n.tr("Stopped"), held: I18n.tr("Held"), error: I18n.tr("Error") })
    // A CUPS message that is an error (e.g. «gstoraster filter failed»)
    function isError(t) { return /fail|error|unable|stopped|not responding|offline/i.test(t) }

    function rows(text, tag) { return text.split("\n").filter(l => l.startsWith(tag + "|")).map(l => l.split("|")) }
    function load() { stateProc.running = true }
    Component.onCompleted: load()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.load() }
    Connections {
        target: ShellState
        function onSettingsChanged() { page.load() }
    }

    Process {
        id: stateProc
        command: [page.script, "estado"]
        stdout: StdioCollector {
            onStreamFinished: {
                const c = page.rows(text, "cups")[0]
                if (c) { page.installed = c[1] === "1"; page.active = c[2] === "1"; page.ghostscript = c[3] !== "0" }
                page.printers = page.rows(text, "impresora").map(r => ({ name: r[1], state: r[2], isDefault: r[3] === "1", uri: r[4], detail: r.slice(5).join("|") }))
                page.jobs = page.rows(text, "trabajo").map(r => ({ id: r[1], printer: r[2], user: r[3], bytes: +r[4], state: r[5], date: r.slice(6).join("|") }))
                page.loaded = true
            }
        }
    }
    Process {
        id: findProc
        command: [page.script, "buscar"]
        stdout: StdioCollector {
            onStreamFinished: {
                const a = page.rows(text, "avahi")[0]
                page.avahi = !a || a[1] === "1"
                page.found = page.rows(text, "dispositivo").map(r => ({ kind: r[1], uri: r[2], name: r[3], desc: r[4], ipUri: r[5] ?? "" }))
                page.searched = true
            }
        }
    }
    // Actions without sudo: default, test and cancel
    Process {
        id: actProc
        stderr: StdioCollector { id: actErr }
        onExited: code => { if (code !== 0) page.message = actErr.text.trim() || I18n.tr("It did not work"); page.load() }
    }
    function act(args, msg) { message = msg; actProc.command = [script].concat(args); actProc.running = true }

    // Add without drivers (IPP Everywhere). Each address is tried in order: the one with the network
    // name (dnssd://, still valid if the IP changes) and, if it fails (lpadmin has to talk to
    // the printer and without nss-mdns it does not resolve «.local»), by IP. If none works, it points to the
    // manufacturer's driver.
    // A text for a bash command, single-quoted (for the messages printed in the terminal)
    function q(s) { return "'" + s.replace(/'/g, "'\\''") + "'" }
    function add(name, uri, ipUri) {
        Terminal.run(I18n.tr("Add printer"),
            'n=$1; shift; ok=; for u in "$@"; do [ -n "$u" ] || continue; printf ' + q(I18n.tr("Trying %s") + "\\n") + ' "$u"; ' +
            'if sudo lpadmin -p "$n" -E -v "$u" -m everywhere; then ok=$u; break; fi; echo; done; ' +
            'if [ -n "$ok" ]; then echo; printf ' + q(I18n.tr("Added: %s") + "\\n") + ' "$n"; ' +
            '[ -z "$(lpstat -d 2>/dev/null | sed -n "s/^system default destination: //p")" ] && lpoptions -d "$n" >/dev/null && echo ' + q(I18n.tr("It is the default one")) + '; ' +
            'else echo ' + q(I18n.tr("Could not add it without drivers. If it says above that the printer is not found, check the network;")) + '; ' +
            'echo ' + q(I18n.tr("otherwise it needs the manufacturer's driver (e.g. hplip for HP, brlaser for Brother, cnijfilter2 for Canon)")) + '; exit 1; fi',
            [name, uri].concat(ipUri ? [ipUri] : []))
    }
    readonly property var addedUris: printers.map(p => p.uri)

    BarText {
        visible: page.message !== ""
        text: page.message
        color: Theme.fgSoft; font.pixelSize: 12
        wrapMode: Text.Wrap; Layout.fillWidth: true
    }

    // --- No CUPS ---
    SettingsGroup {
        visible: page.loaded && (!page.installed || !page.active)
        SettingsRow {
            text: page.installed ? I18n.tr("The print service is stopped") : I18n.tr("No printing support")
            description: page.installed ? I18n.tr("CUPS is installed but not active")
                : I18n.tr("CUPS and avahi (to find printers on the network) are installed and enabled")
            Button {
                kind: "primary"; icon: "󰐪"
                text: page.installed ? I18n.tr("Enable") : I18n.tr("Install")
                onClicked: Terminal.run(I18n.tr("Printing setup"), page.installed
                    ? "sudo systemctl enable --now cups.socket cups.service"
                    : "sudo pacman -S --needed cups cups-filters ghostscript avahi nss-mdns && sudo systemctl enable --now cups.socket cups.service avahi-daemon.service")
            }
        }
    }

    // --- Ghostscript missing ---
    Rectangle {
        visible: page.loaded && page.installed && page.active && !page.ghostscript
        Layout.fillWidth: true
        implicitHeight: gsRow.implicitHeight + 24
        radius: Theme.cardRadius
        color: Theme.selSoft
        border.color: Theme.sel; border.width: 1
        RowLayout {
            id: gsRow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                BarText { text: I18n.tr("Ghostscript is missing"); font.bold: true }
                BarText {
                    Layout.fillWidth: true
                    text: I18n.tr("The CUPS filters use it to prepare what is printed; without it jobs fail («gstoraster filter failed»)")
                    color: Theme.fgSoft; font.pixelSize: 11; wrapMode: Text.Wrap
                }
            }
            Button {
                kind: "primary"; text: I18n.tr("Install")
                onClicked: Terminal.run("Ghostscript", "sudo pacman -S --needed ghostscript && sudo systemctl restart cups.service")
            }
        }
    }

    // --- Configured ---
    SettingsGroup {
        visible: page.installed && page.active
        label: I18n.tr("Printers")
        BarText { visible: page.printers.length === 0; text: page.loaded ? I18n.tr("There are none: add one below") : I18n.tr("Loading…"); color: Theme.dim }
        Repeater {
            model: page.printers
            delegate: ColumnLayout {
                id: pr
                required property var modelData
                readonly property bool asking: page.confirm === modelData.name
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    BarText { text: "󰐪"; font.pixelSize: 18; color: pr.modelData.state === "printing" ? Theme.sel : Theme.fgSoft }
                    BarText { text: pr.modelData.name.replace(/_/g, " "); font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    Button {
                        visible: !pr.modelData.isDefault && !pr.asking
                        kind: "ghost"; text: I18n.tr("Default")
                        onClicked: page.act(["predeterminada", pr.modelData.name], I18n.tr("«%1» is the default").arg(pr.modelData.name))
                    }
                    Button {
                        visible: pr.modelData.state === "disabled" && !pr.asking
                        text: I18n.tr("Resume")
                        onClicked: Terminal.run(I18n.tr("Resume"), 'sudo cupsenable "$1" && sudo cupsaccept "$1"', [pr.modelData.name])
                    }
                    Button {
                        visible: pr.modelData.state !== "disabled" && !pr.asking
                        icon: "󰈙"; text: I18n.tr("Test")
                        onClicked: page.act(["prueba", pr.modelData.name], I18n.tr("Test page sent to «%1»").arg(pr.modelData.name))
                    }
                    Button { visible: pr.asking; kind: "ghost"; text: I18n.tr("Cancel"); onClicked: page.confirm = "" }
                    Button {
                        visible: pr.asking
                        kind: "primary"; text: I18n.tr("Remove")
                        onClicked: {
                            page.confirm = ""
                            Terminal.run(I18n.tr("Remove printer"), 'sudo lpadmin -x "$1" && printf ' + page.q(I18n.tr("Removed: %s") + "\\n") + ' "$1"', [pr.modelData.name])
                        }
                    }
                    IconButton { visible: !pr.asking; danger: true; onClicked: page.confirm = pr.modelData.name }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 26
                    spacing: 6
                    Tag { text: page.stateNames[pr.modelData.state] ?? pr.modelData.state }
                    Tag { visible: pr.modelData.isDefault; text: I18n.tr("Default") }
                    BarText { height: 18; text: pr.modelData.uri; color: Theme.dim; font.pixelSize: 11 }
                }
                BarText {
                    visible: pr.modelData.detail !== "" || pr.asking
                    Layout.leftMargin: 26
                    text: pr.asking ? I18n.tr("It is removed from CUPS (pending jobs are lost). Sure?")
                        : (page.isError(pr.modelData.detail) ? "󰀦  " : "") + pr.modelData.detail
                    color: pr.asking ? Theme.fg : page.isError(pr.modelData.detail) ? Theme.red : Theme.dim; font.pixelSize: 11
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 6; implicitHeight: 1; color: Theme.control }
            }
        }
    }

    // --- Queue ---
    SettingsGroup {
        visible: page.installed && page.active && page.printers.length > 0
        label: page.jobs.length ? I18n.tr("Print queue") + " · " + page.jobs.length : I18n.tr("Print queue")
        BarText { visible: page.jobs.length === 0; text: I18n.tr("Nothing queued"); color: Theme.dim }
        Repeater {
            model: page.jobs
            delegate: RowLayout {
                id: job
                required property var modelData
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Row {
                        Layout.fillWidth: true
                        spacing: 8
                        BarText { text: job.modelData.id + "  ·  " + job.modelData.user; anchors.verticalCenter: parent.verticalCenter }
                        Tag { text: page.jobStates[job.modelData.state] ?? job.modelData.state; anchors.verticalCenter: parent.verticalCenter }
                    }
                    BarText {
                        // If it stopped, the reason is its printer's message
                        readonly property string why: (job.modelData.state === "stopped" || job.modelData.state === "error")
                            ? (page.printers.find(p => p.name === job.modelData.printer)?.detail ?? "") : ""
                        text: why ? "󰀦  " + why : job.modelData.date
                        color: why ? Theme.red : Theme.dim
                        font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
                Button {
                    visible: job.modelData.state === "stopped" || job.modelData.state === "error" || job.modelData.state === "held"
                    icon: "󰑐"; text: I18n.tr("Retry")
                    onClicked: page.act(["reintentar", job.modelData.id], I18n.tr("Job %1 sent again").arg(job.modelData.id))
                }
                Button {
                    icon: "󰅖"; text: I18n.tr("Cancel")
                    onClicked: page.act(["cancelar", job.modelData.id], I18n.tr("Job %1 cancelled").arg(job.modelData.id))
                }
            }
        }
    }

    // --- Add ---
    SettingsGroup {
        visible: page.installed && page.active
        label: I18n.tr("Add a printer")
        SettingsRow {
            text: I18n.tr("Search the network and USB")
            description: I18n.tr("Network ones (through avahi) and USB ones. They are added without drivers (IPP Everywhere / AirPrint): it works for almost every printer from recent years")
            Button {
                kind: "primary"; icon: "󰍉"; text: I18n.tr("Search")
                busy: findProc.running
                onClicked: { page.found = []; findProc.running = true }
            }
        }
        // Without avahi nothing is announced on the network
        Rectangle {
            visible: page.searched && !page.avahi
            Layout.fillWidth: true
            implicitHeight: avahiRow.implicitHeight + 20
            radius: 10
            color: Theme.selSoft
            border.color: Theme.sel; border.width: 1
            RowLayout {
                id: avahiRow
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                spacing: 10
                BarText {
                    Layout.fillWidth: true
                    text: I18n.tr("avahi is not active: without it network printers are not seen (Wi-Fi ones announce themselves through it)")
                    wrapMode: Text.Wrap; font.pixelSize: 12
                }
                Button {
                    kind: "primary"; text: I18n.tr("Enable avahi")
                    onClicked: Terminal.run("avahi", "sudo pacman -S --needed avahi nss-mdns && sudo systemctl enable --now avahi-daemon.service")
                }
            }
        }
        BarText {
            visible: findProc.running || (page.searched && page.avahi && page.found.length === 0)
            text: findProc.running ? I18n.tr("Searching… (it takes a few seconds)")
                : I18n.tr("None found. Check that it is on and connected to the same Wi-Fi network, or add it by its IP (shown on its screen: LAN settings)")
            color: Theme.dim; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
        Repeater {
            model: page.found
            delegate: RowLayout {
                id: dev
                required property var modelData
                readonly property bool added: page.addedUris.includes(modelData.uri) || (modelData.ipUri !== "" && page.addedUris.includes(modelData.ipUri))
                Layout.fillWidth: true
                spacing: 10
                BarText { text: dev.modelData.kind === "direct" ? "󰗜" : "󰖩"; color: Theme.fgSoft; font.pixelSize: 16 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    BarText { text: dev.modelData.desc; elide: Text.ElideRight; Layout.fillWidth: true }
                    BarText { text: (dev.modelData.kind === "direct" ? "USB · " : I18n.tr("Network") + " · ") + decodeURIComponent(dev.modelData.uri); color: Theme.dim; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth: true }
                }
                Rectangle {
                    visible: dev.added
                    Layout.preferredWidth: 110; implicitHeight: 32; radius: Theme.controlRadius
                    color: Theme.selSoft
                    BarText { anchors.centerIn: parent; text: "󰄬  " + I18n.tr("Added", "printer"); font.pixelSize: 12; color: Theme.sel }
                }
                Button {
                    visible: !dev.added
                    Layout.preferredWidth: 110
                    icon: "󰐕"; text: I18n.tr("Add")
                    onClicked: page.add(dev.modelData.name, dev.modelData.uri, dev.modelData.ipUri)
                }
            }
        }
        // By address
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 8
            WifiField { id: host; Layout.fillWidth: true; placeholder: I18n.tr("Or by its address: IP or name (e.g. 192.168.1.50)") }
            WifiField { id: hostName; Layout.preferredWidth: 170; placeholder: I18n.tr("Name (optional)") }
            Button {
                text: I18n.tr("Add")
                enabled: host.text.trim() !== ""
                onClicked: {
                    const h = host.text.trim()
                    const n = (hostName.text.trim() || "Impresora_" + h).replace(/[^A-Za-z0-9_-]+/g, "_")
                    page.add(n, h.includes("://") ? h : "ipp://" + h + "/ipp/print")
                    host.text = ""; hostName.text = ""
                }
            }
        }
    }
}
