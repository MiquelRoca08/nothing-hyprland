# Module: boot (kernel options, Plymouth disabled, initramfs)
TITLE=$(t "Boot")
DESCRIPTION=$(t "Quiet boot (docs/SYSTEM.md, «Quiet boot»): adds the missing options to each cmdline of /boot/limine.conf (snapshots included), masks Plymouth (it left the NVIDIA monitor without a picture) and, if the previous module changed something in the initramfs, rebuilds the UKI with mkinitcpio -P (sbctl signs it by itself).")

KERNEL_OPTIONS=(quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false
          rd.systemd.show_status=false vt.global_cursor_default=0 plymouth.enable=0)

# On every «cmdline:», add the missing options and fix the value of those set differently
add_kernel_options() {   # add_kernel_options file
    local opt key
    for opt in "${KERNEL_OPTIONS[@]}"; do
        key=${opt%%=*}
        sed -i -E "/^\s*cmdline:/{
            s/(\s)${key//./\\.}=[^ ]*/\1$opt/
            / ${key//./\\.}(=| |$)/!s/$/ $opt/
        }" "$1"
    done
}

module() {
    local changed=false tmp
    if [ -f /boot/limine.conf ]; then
        tmp=$(mktemp)
        cat /boot/limine.conf >"$tmp" 2>/dev/null || sudo cat /boot/limine.conf >"$tmp"
        cp "$tmp" "$tmp.new"
        add_kernel_options "$tmp.new"
        # No branding text at the top of the menu (it used to say «archlinux»)
        sed -i -E 's/^(\s*interface_branding:).*/\1/' "$tmp.new"
        if ! cmp -s "$tmp" "$tmp.new"; then
            changed=true; info "$(t "Changes to /boot/limine.conf:")"
            diff "$tmp" "$tmp.new" | sed -n 's/^> */    /p'
            step "$(t "Update /boot/limine.conf (silent boot options, no branding text)")" \
                sudo cp "$tmp.new" /boot/limine.conf
        fi
        rm -f "$tmp" "$tmp.new"
    fi
    # In case plymouth.enable=0 is missing or mistyped (it once was «plymouth.enable)0»)
    if systemctl list-unit-files plymouth-start.service >/dev/null 2>&1 &&
       [ "$(systemctl is-enabled plymouth-start.service 2>/dev/null)" != masked ]; then
        changed=true; step "$(t "Mask plymouth-start.service (Plymouth disabled)")" sudo systemctl mask plymouth-start.service
    fi
    if [ -e "$STATE/initramfs" ]; then
        changed=true; step "$(t "Rebuild the boot image (initramfs files changed)")" sudo mkinitcpio -P
    fi
    $changed || nothing_to_do "$(t "the kernel options and Plymouth are already fine")"
}
