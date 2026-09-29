# Module: boot (kernel options, Plymouth disabled, initramfs)
TITULO=$(t "Boot")
DESCRIPCION=$(t "Quiet boot (docs/SYSTEM.md, «Quiet boot»): adds the missing options to each cmdline of /boot/limine.conf (snapshots included), masks Plymouth (it left the NVIDIA monitor without a picture) and, if the previous module changed something in the initramfs, rebuilds the UKI with mkinitcpio -P (sbctl signs it by itself).")

OPCIONES=(quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false
          rd.systemd.show_status=false vt.global_cursor_default=0 plymouth.enable=0)

# On every «cmdline:», add the missing options and fix the value of those set differently
con_opciones() {   # con_opciones file
    local op clave
    for op in "${OPCIONES[@]}"; do
        clave=${op%%=*}
        sed -i -E "/^\s*cmdline:/{
            s/(\s)${clave//./\\.}=[^ ]*/\1$op/
            / ${clave//./\\.}(=| |$)/!s/$/ $op/
        }" "$1"
    done
}

modulo() {
    local hay=false tmp
    if [ -f /boot/limine.conf ]; then
        tmp=$(mktemp)
        cat /boot/limine.conf >"$tmp" 2>/dev/null || sudo cat /boot/limine.conf >"$tmp"
        cp "$tmp" "$tmp.nuevo"
        con_opciones "$tmp.nuevo"
        # No branding text at the top of the menu (it used to say «archlinux»)
        sed -i -E 's/^(\s*interface_branding:).*/\1/' "$tmp.nuevo"
        if ! cmp -s "$tmp" "$tmp.nuevo"; then
            hay=true; info "$(t "Changes to /boot/limine.conf:")"
            diff "$tmp" "$tmp.nuevo" | sed -n 's/^> */    /p'
            paso "$(t "Update /boot/limine.conf (silent boot options, no branding text)")" \
                sudo cp "$tmp.nuevo" /boot/limine.conf
        fi
        rm -f "$tmp" "$tmp.nuevo"
    fi
    # In case plymouth.enable=0 is missing or mistyped (28 Sep: «plymouth.enable)0»)
    if systemctl list-unit-files plymouth-start.service >/dev/null 2>&1 &&
       [ "$(systemctl is-enabled plymouth-start.service 2>/dev/null)" != masked ]; then
        hay=true; paso "$(t "Mask plymouth-start.service (Plymouth disabled)")" sudo systemctl mask plymouth-start.service
    fi
    if [ -e "$ESTADO/initramfs" ]; then
        hay=true; paso "$(t "Rebuild the boot image (initramfs files changed)")" sudo mkinitcpio -P
    fi
    $hay || nada "$(t "the kernel options and Plymouth are already fine")"
}
