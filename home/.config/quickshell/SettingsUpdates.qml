// Settings → Updates: pending ones (UpdateService) and each way to update, in the menu's floating
// terminal (Terminal). «Whole system» and «Repositories only» go through scripts/update.sh
// (arch-update --menu: snapshot, boot checks and a «Close» button at the end); the rest
// wait for a key when done. setsid: so they do not depend on qs, which arch-update restarts.
// Before updating you can see which packages change (from which version to which; the ones that need a reboot,
// marked), and a snapshot can be taken without updating (scripts/snapshot.sh).
import Quickshell
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Updates")
    subtitle: I18n.tr("They open in a floating terminal; when done, it stays open until you close it")
    readonly property var u: UpdateService
    property bool snapshotting: false
    Component.onCompleted: UpdateService.check(false)
    // When an update finishes (Terminal.run or update.sh notify), it counts again
    Connections {
        target: ShellState
        function onSettingsChanged() { page.snapshotting = false; UpdateService.check(true) }
    }

    property var expanded: ({})     // lists expanded in full (more than 12)
    // Like arch-update: a new kernel or Hyprland needs a reboot
    function needsReboot(name) { return /^(linux(-lts|-zen|-hardened)?|hyprland)$/.test(name) }
    function count(n) { return n === -1 ? I18n.tr("checking…") : n === -2 ? I18n.tr("not available") : n === 0 ? I18n.tr("up to date") : I18n.tr("%1 pending").arg(n) }
    SettingsGroup {
        SettingsRow {
            text: page.u.checking ? I18n.tr("Checking…")
                : page.u.total === 0 ? I18n.tr("The system is up to date")
                : I18n.trn(page.u.total, "%1 pending update", "%1 pending updates")
            description: I18n.tr("Repositories: %1 · AUR: %2 · Flatpak: %3").arg(page.count(page.u.repo)).arg(page.count(page.u.aur)).arg(page.count(page.u.flatpak))
            Button { icon: "󰑐"; text: I18n.tr("Check"); busy: page.u.checking; onClicked: UpdateService.check(true) }
        }
    }

    // --- What will be updated ---
    Repeater {
        model: [
            { k: "repo", label: I18n.tr("Repositories"), list: page.u.repoList },
            { k: "aur", label: "AUR", list: page.u.aurList },
            { k: "flatpak", label: "Flatpak", list: page.u.flatpakList },
        ].filter(g => g.list.length > 0)
        delegate: SettingsGroup {
            id: grp
            required property var modelData
            readonly property bool all: page.expanded[modelData.k] === true
            label: modelData.label + " · " + modelData.list.length
            Repeater {
                model: grp.all ? grp.modelData.list : grp.modelData.list.slice(0, 12)
                delegate: RowLayout {
                    id: pkg
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    BarText { text: pkg.modelData.name; elide: Text.ElideRight; Layout.fillWidth: true }
                    Tag { visible: page.needsReboot(pkg.modelData.name); text: I18n.tr("Needs a reboot") }
                    BarText { visible: pkg.modelData.from !== ""; text: pkg.modelData.from; color: Theme.dim; font.pixelSize: 12 }
                    BarText { visible: pkg.modelData.from !== ""; text: "→"; color: Theme.dim; font.pixelSize: 12 }
                    BarText { text: pkg.modelData.to; color: Theme.fg; font.pixelSize: 12 }
                }
            }
            Button {
                visible: grp.modelData.list.length > 12
                kind: "ghost"
                text: grp.all ? I18n.tr("Show less") : I18n.tr("Show all %1").arg(grp.modelData.list.length)
                onClicked: {
                    const e = Object.assign({}, page.expanded)
                    e[grp.modelData.k] = !grp.all
                    page.expanded = e
                }
            }
        }
    }

    SettingsGroup {
        label: I18n.tr("Update")
        SettingsRow {
            text: I18n.tr("Whole system")
            description: I18n.tr("Snapshot, repositories and AUR, cleanup and boot check (arch-update)")
            Button { kind: "primary"; icon: "󰚰"; text: I18n.tr("Update"); onClicked: Terminal.open(I18n.tr("Update"), [Quickshell.shellPath("scripts/update.sh")]) }
        }
        SettingsRow {
            text: I18n.tr("Repositories only")
            description: I18n.tr("Like the previous one, without the AUR (arch-update --no-aur)")
            Button { text: I18n.tr("Update"); onClicked: Terminal.open(I18n.tr("Update"), [Quickshell.shellPath("scripts/update.sh"), "--no-aur"]) }
        }
        SettingsRow {
            text: I18n.tr("AUR only")
            description: I18n.tr("yay -Sua, no snapshot")
            Button { text: I18n.tr("Update"); onClicked: Terminal.run("AUR", "yay -Sua") }
        }
        SettingsRow {
            text: "Flatpak"
            description: "flatpak update"
            Button { text: I18n.tr("Update"); onClicked: Terminal.run("Flatpak", "flatpak update") }
        }
        SettingsRow {
            text: "Firmware"
            description: I18n.tr("BIOS and supported devices (fwupdmgr)")
            Button { text: I18n.tr("Update"); onClicked: Terminal.run("Firmware", "fwupdmgr refresh && fwupdmgr update") }
        }
    }

    // --- Snapshot without updating ---
    SettingsGroup {
        label: "Snapshot"
        SettingsRow {
            text: I18n.tr("Create a snapshot now")
            description: I18n.tr("Of the system as it is, to go back to it from the Limine menu. It replaces the previous one: only one is kept (also the one «Update» takes before starting)")
            Button {
                kind: "primary"; icon: "󰆓"; text: I18n.tr("Create")
                busy: page.snapshotting
                onClicked: {
                    page.snapshotting = true
                    Terminal.run("Snapshot", '"$1" "$2"', [Quickshell.shellPath("scripts/snapshot.sh"), snapDesc.text.trim()])
                    snapDesc.text = ""
                }
            }
        }
        WifiField {
            id: snapDesc
            Layout.fillWidth: true
            placeholder: I18n.tr("Description (optional, e.g. «before touching Hyprland»)")
        }
    }

    SettingsGroup {
        label: I18n.tr("Maintenance")
        SettingsRow {
            text: I18n.tr("Restart the shell")
            description: I18n.tr("After changing quickshell files that do not reload by themselves")
            Button { text: I18n.tr("Restart"); onClicked: Quickshell.execDetached(["sh", "-c", "pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd(\"qs\")'"]) }
        }
        SettingsRow {
            text: I18n.tr("Restart walker")
            description: I18n.tr("Launcher and system menu (walker and elephant)")
            Button { text: I18n.tr("Restart"); onClicked: Quickshell.execDetached(["walker-restart"]) }
        }
    }
}
