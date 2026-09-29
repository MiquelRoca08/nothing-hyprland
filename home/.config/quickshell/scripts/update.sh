#!/usr/bin/env bash
# Updates the system from the shell (Settings → Updates) and from the walker menu. It runs
# inside the menu's floating terminal (class menu-terminal):
#   alacritty --class menu-terminal --title Actualizar -e ~/.config/quickshell/scripts/update.sh [--no-aur]
# The terminal does not close by itself when done: arch-update --menu waits for its «Close» button
# and exits with 200 to say it already did; with any other exit (an old arch-update without --menu,
# an error before starting, no arch-update…) it waits for a key here.

source "$(dirname "$(readlink -f "$0")")/../i18n/i18n.sh" 2>/dev/null ||
    t() { local s=$1; shift; if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi; }
wait_key() {
    echo
    while read -t 0.05 -n 1 -s; do :; done # extra keystrokes do not close it
    read -n 1 -s -r -p "${1:-$(t "Press a key to close…")}"
}

sudo -v || { wait_key "$(t "No sudo permission. Press a key to close…")"; exit 1; }

if [[ -x /usr/local/bin/arch-update ]]; then
    if grep -q -- '--menu)' /usr/local/bin/arch-update; then
        sudo /usr/local/bin/arch-update --menu "$@"
    else
        echo "$(t "Warning: /usr/local/bin/arch-update is an old version (./install.sh system updates it)")"
        sudo /usr/local/bin/arch-update "$@"
    fi
    e=$?
    qs ipc call settings changed >/dev/null 2>&1   # Settings recounts the pending updates
    ((e == 200)) && exit 0
else
    echo "$(t "arch-update is not installed (./install.sh system): using yay -Syu")"
    yay -Syu
    qs ipc call settings changed >/dev/null 2>&1
fi
wait_key
