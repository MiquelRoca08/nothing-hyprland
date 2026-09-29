# Module: files from system/ into / (sudo)
TITLE=$(t "System files")
DESCRIPTION=$(t "Copies to / the files of system/ that have changed (greetd, PAM, Howdy, Limine, mkinitcpio, arch-update, G14 audio…). Some are templates: they are filled in with this machine's data (@USER@, @HOME@, @MACHINE_ID@ and @ROOT_PARTUUID@). /boot/limine.conf is not overwritten if it already has limine-snapper-sync's snapshots, and the mixer state (asound.state) is only copied if it does not exist. It also deletes from /etc the files the repo no longer has.")

# Paths the repo used to have (install.sh only copies: they would stay in /)
OLD_PATHS=(
    /etc/systemd/system/greetd.service.d/plymouth.conf
    /etc/systemd/system/plymouth-quit.service.d/retener.conf
    /etc/pam.d/quickshell-lock-cara
)

# This machine's data for the templates
ROOT_DEV=$(findmnt -no SOURCE / | sed 's/\[.*//')
ROOT_PARTUUID=$(lsblk -no PARTUUID "$ROOT_DEV" 2>/dev/null)
MACHINE_ID=$(cat /etc/machine-id 2>/dev/null)

# The file as it will end up in / (templates filled in), at $STATE/system/<path>
render() {
    local f=$1 out="$STATE/system/${1#./}"
    mkdir -p "$(dirname "$out")"
    if grep -qI '@[A-Z_]*@' "$DOT/system/$f" 2>/dev/null; then
        sed -e "s|@USER@|$USER|g" -e "s|@HOME@|$HOME|g" \
            -e "s|@MACHINE_ID@|$MACHINE_ID|g" -e "s|@ROOT_PARTUUID@|$ROOT_PARTUUID|g" "$DOT/system/$f" >"$out"
    else
        cp "$DOT/system/$f" "$out"
    fi
    echo "$out"
}

copy_files() {   # copy_files relative-path…
    local f dst mode
    for f; do
        dst="/${f#./}"
        mode=644; [ -x "$DOT/system/$f" ] && mode=755     # keeps executables executable (arch-update)
        sudo install -Dm$mode "$STATE/system/${f#./}" "$dst" && ok_msg "$dst" || return
        case $dst in
        /etc/mkinitcpio* | /etc/initcpio/* | /usr/lib/firmware/* | /etc/modprobe.d/* | /etc/plymouth/* | \
        /usr/share/plymouth/* | /usr/local/share/nothing/*) touch "$STATE/initramfs" ;;   # used by the boot module
        esac
    done
}

module() {
    local f dst pending=() old=()
    while read -r f; do
        dst="/${f#./}"
        excluded_items - 5 | grep -qx "$dst" && continue     # its feature was left out (features module)
        case $dst in
        /boot/limine.conf)
            if grep -q 'limine-snapper-sync' "$dst" 2>/dev/null; then
                info "$(t "%s: not overwritten (it has the snapshots; the template is system/boot/limine.conf)" "$dst")"; continue
            fi
            [ -n "$ROOT_PARTUUID" ] || { warn "$(t "skipping %s: could not read the root PARTUUID" "$dst")"; continue; } ;;
        /var/lib/alsa/asound.state) [ -e "$dst" ] && continue ;;   # alsa saves it on shutdown
        esac
        cmp -s "$(render "$f")" "$dst" 2>/dev/null || pending+=("$f")
    done < <(cd "$DOT/system" && find . -type f | sort)
    for f in "${OLD_PATHS[@]}"; do [ -e "$f" ] && old+=("$f"); done

    ((${#pending[@]} + ${#old[@]})) || { nothing_to_do "$(t "/ already matches system/")"; return; }
    if ((${#pending[@]})); then
        info "$(t "Changed:")"; printf '    /%s\n' "${pending[@]#./}"
        step "$(t "Copy %s files from system/ to /" "${#pending[@]}")" copy_files "${pending[@]}"
    fi
    if ((${#old[@]})); then
        step "$(t "Delete what the repo no longer has")" sudo rm -f "${old[@]}"
    fi
    step "$(t "Reload systemd (in case units or drop-ins changed)")" sudo systemctl daemon-reload
}
