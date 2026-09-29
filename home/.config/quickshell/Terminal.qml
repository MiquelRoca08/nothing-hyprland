pragma Singleton
// Opens commands in the menu's floating terminal (Alacritty, class menu-terminal), for Settings.
// setsid -f: so they do not depend on qs (arch-update, for example, restarts it).
//   open(title, [program, args…])     as is (the program decides whether it waits at the end)
//   run(title, "bash command")        waits for a key when done (unless cut with Ctrl+C);
//                                     right after the command ends it tells Settings (IPC settings
//                                     changed → ShellState.settingsChanged) so it reloads.
//                                     args: separate arguments ($1, $2… in the command), with no
//                                     quoting problems
import Quickshell
import QtQuick

Singleton {
    function open(title, args) {
        Quickshell.execDetached(["setsid", "-f", "alacritty", "--class", "menu-terminal", "--title", title, "-e"].concat(args))
    }
    function run(title, cmd, args) {
        open(title, ["bash", "-c", cmd + "; e=$?; qs ipc call settings changed >/dev/null 2>&1; ((e == 130)) && exit; " +
                     "echo; while read -t 0.05 -n 1 -s; do :; done; " +
                     "read -n 1 -s -r -p '" + I18n.tr("Done. Press a key to close…") + "'", "bash"].concat(args ?? []))
    }
}
