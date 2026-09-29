# Module: files from system/ into / (sudo)
TITULO=$(t "System files")
DESCRIPCION=$(t "Copies to / the files of system/ that have changed (greetd, PAM, Howdy, Limine, mkinitcpio, arch-update, G14 audio…). Some are templates: they are filled in with this machine's data (@USUARIO@, @HOME@, @MACHINE_ID@ and @PARTUUID_RAIZ@). /boot/limine.conf is not overwritten if it already has limine-snapper-sync's snapshots, and the mixer state (asound.state) is only copied if it does not exist. It also deletes from /etc the files the repo no longer has.")

# Paths the repo used to have (install.sh only copies: they would stay in /)
VIEJOS=(
    /etc/systemd/system/greetd.service.d/plymouth.conf
    /etc/systemd/system/plymouth-quit.service.d/retener.conf
)

# This machine's data for the templates
RAIZ_DEV=$(findmnt -no SOURCE / | sed 's/\[.*//')
PARTUUID_RAIZ=$(lsblk -no PARTUUID "$RAIZ_DEV" 2>/dev/null)
MACHINE_ID=$(cat /etc/machine-id 2>/dev/null)

# The file as it will end up in / (templates filled in), at $ESTADO/sistema/<path>
renderizar() {
    local f=$1 out="$ESTADO/sistema/${1#./}"
    mkdir -p "$(dirname "$out")"
    if grep -qI '@[A-Z_]*@' "$DOT/system/$f" 2>/dev/null; then
        sed -e "s|@USUARIO@|$USER|g" -e "s|@HOME@|$HOME|g" \
            -e "s|@MACHINE_ID@|$MACHINE_ID|g" -e "s|@PARTUUID_RAIZ@|$PARTUUID_RAIZ|g" "$DOT/system/$f" >"$out"
    else
        cp "$DOT/system/$f" "$out"
    fi
    echo "$out"
}

copiar() {   # copiar relative-path…
    local f dst mode
    for f; do
        dst="/${f#./}"
        mode=644; [ -x "$DOT/system/$f" ] && mode=755     # keeps executables executable (arch-update)
        sudo install -Dm$mode "$ESTADO/sistema/${f#./}" "$dst" && hecho "$dst" || return
        case $dst in
        /etc/mkinitcpio* | /etc/initcpio/* | /usr/lib/firmware/* | /etc/modprobe.d/* | /etc/plymouth/* | \
        /usr/share/plymouth/* | /usr/local/share/nothing/*) touch "$ESTADO/initramfs" ;;   # used by the boot module
        esac
    done
}

modulo() {
    local f dst pend=() viejos=()
    while read -r f; do
        dst="/${f#./}"
        case $dst in
        /boot/limine.conf)
            if grep -q 'limine-snapper-sync' "$dst" 2>/dev/null; then
                info "$(t "%s: not overwritten (it has the snapshots; the template is system/boot/limine.conf)" "$dst")"; continue
            fi
            [ -n "$PARTUUID_RAIZ" ] || { aviso "$(t "skipping %s: could not read the root PARTUUID" "$dst")"; continue; } ;;
        /var/lib/alsa/asound.state) [ -e "$dst" ] && continue ;;   # alsa saves it on shutdown
        esac
        cmp -s "$(renderizar "$f")" "$dst" 2>/dev/null || pend+=("$f")
    done < <(cd "$DOT/system" && find . -type f | sort)
    for f in "${VIEJOS[@]}"; do [ -e "$f" ] && viejos+=("$f"); done

    ((${#pend[@]} + ${#viejos[@]})) || { nada "$(t "/ already matches system/")"; return; }
    if ((${#pend[@]})); then
        info "$(t "Changed:")"; printf '    /%s\n' "${pend[@]#./}"
        paso "$(t "Copy %s files from system/ to /" "${#pend[@]}")" copiar "${pend[@]}"
    fi
    if ((${#viejos[@]})); then
        paso "$(t "Delete what the repo no longer has")" sudo rm -f "${viejos[@]}"
    fi
    paso "$(t "Reload systemd (in case units or drop-ins changed)")" sudo systemctl daemon-reload
}
