// Settings → Personalization → QuickShell → Lock screen: idle timeouts (lock,
// screens off, suspend; Config.qml generates ~/.config/hypr/hypridle.conf and restarts
// hypridle; 0 = never) with a one-sentence summary and warnings if they contradict each other; try the lock
// screen (15 s, IPC lock test) or lock now; and face recognition (Howdy: enroll the
// face or install it).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Lock screen")
    subtitle: I18n.tr("When it locks, turns the screens off and suspends; try it out, and face recognition")
    readonly property var o: Config.options
    property string face: ""        // "on" (Howdy and its PAM), "installed" (no PAM), "no"

    Process {
        running: true
        command: ["sh", "-c", "command -v howdy >/dev/null || { echo no; exit; }; " +
                              "test -e /etc/pam.d/quickshell-lock-face && echo on || echo installed"]
        stdout: StdioCollector { onStreamFinished: page.face = text.trim() }
    }

    function mins(m) { return I18n.trn(m, "%1 minute", "%1 minutes") }
    readonly property string summary: {
        const p = []
        p.push(o.lockMinutes > 0 ? I18n.tr("Locks after %1 without use").arg(mins(o.lockMinutes)) : I18n.tr("Does not lock by itself"))
        p.push(o.screenOffMinutes > 0 ? I18n.tr("screens turn off after %1").arg(mins(o.screenOffMinutes)) : I18n.tr("screens do not turn off"))
        p.push(o.suspendMinutes > 0 ? I18n.tr("suspends after %1").arg(mins(o.suspendMinutes)) : I18n.tr("does not suspend"))
        return p.join(" · ")
    }
    // Combinations that make little sense
    readonly property string warning: {
        const l = o.lockMinutes, s = o.screenOffMinutes, z = o.suspendMinutes
        if (z > 0 && s > 0 && s >= z) return I18n.tr("The screens would turn off after suspending: it never happens")
        if (z > 0 && l > 0 && l >= z) return I18n.tr("It suspends before it is time to lock (suspending locks too)")
        if (l === 0 && s > 0) return I18n.tr("The screens turn off but the session stays open: anyone can use it on return")
        return ""
    }

    // Summary
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: sum.implicitHeight + 28
        radius: Theme.cardRadius
        color: Theme.selSoft
        border.color: Theme.sel; border.width: 1
        ColumnLayout {
            id: sum
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
            spacing: 6
            BarText { text: page.summary; wrapMode: Text.Wrap; Layout.fillWidth: true }
            BarText {
                visible: page.warning !== ""
                text: "󰀦  " + page.warning
                color: Theme.red; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("After some time without using the computer")
        SettingsRow {
            text: I18n.tr("Lock the session")
            SliderField { value: o.lockMinutes; from: 0; to: 60; suffix: " min"; zeroText: I18n.tr("Never"); onMoved: v => o.lockMinutes = Math.round(v) }
        }
        SettingsRow {
            text: I18n.tr("Turn the screens off")
            SliderField { value: o.screenOffMinutes; from: 0; to: 120; suffix: " min"; zeroText: I18n.tr("Never"); onMoved: v => o.screenOffMinutes = Math.round(v) }
        }
        SettingsRow {
            text: I18n.tr("Suspend")
            description: I18n.tr("It always locks before suspending")
            SliderField { value: o.suspendMinutes; from: 0; to: 240; suffix: " min"; zeroText: I18n.tr("Never"); onMoved: v => o.suspendMinutes = Math.round(v) }
        }
    }

    SettingsGroup {
        label: I18n.tr("Lock screen")
        SettingsRow {
            text: I18n.tr("See it")
            description: I18n.tr("Try: it locks for 15 s and unlocks by itself, without typing the password. Also from the System menu (Super + Escape)")
            Button { icon: "󰈈"; text: I18n.tr("Try"); onClicked: { ShellState.settingsOpen = false; Quickshell.execDetached(["qs", "ipc", "call", "lock", "test"]) } }
            Button {
                kind: "primary"; icon: "󰌾"; text: I18n.tr("Lock")
                onClicked: { ShellState.settingsOpen = false; Quickshell.execDetached(["bloquear"]) }
            }
        }
        SettingsRow {
            text: I18n.tr("Face recognition")
            description: page.face === "on" ? I18n.tr("On (Howdy with the IR camera): on lock it looks for your face; the password still works")
                       : page.face === "installed" ? I18n.tr("Howdy is installed, but its PAM configuration is missing (./install.sh system)")
                       : page.face === "no" ? I18n.tr("Unlock by looking at the IR camera (Howdy, from the AUR; it builds dlib: it takes a while)")
                       : I18n.tr("Checking…")
            Button {
                visible: page.face === "on" || page.face === "installed"
                icon: "󰄀"; text: I18n.tr("Enroll my face")
                onClicked: Terminal.run("Howdy", "sudo howdy add")
            }
            Button {
                visible: page.face === "no"
                text: I18n.tr("Install")
                onClicked: Terminal.run("Howdy", "yay -S howdy-git && sudo howdy add")
            }
        }
    }
}
