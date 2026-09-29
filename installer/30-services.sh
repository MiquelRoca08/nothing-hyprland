# Module: system services and groups
TITLE=$(t "System services")
DESCRIPTION=$(t "Enables the services the shell and the menus use: network (NetworkManager), Bluetooth, power profiles, printers (cups) and network discovery (avahi). The rest start by themselves through D-Bus. Adds your user to the i2c group (brightness of external monitors through DDC/CI).")

module() {
    local s changed=false
    for s in NetworkManager.service bluetooth.service power-profiles-daemon.service cups.socket avahi-daemon.service; do
        systemctl list-unit-files "$s" >/dev/null 2>&1 || continue
        excluded_items - 4 | grep -qx "$s" && continue     # its feature was left out (features module)
        systemctl is-enabled --quiet "$s" 2>/dev/null && continue
        changed=true
        step "$(t "Enable %s at boot" "$s")" sudo systemctl enable "$s"
    done
    if ! is_excluded ddc && getent group i2c >/dev/null && ! id -nG | grep -qw i2c; then
        changed=true
        step "$(t "Add %s to the i2c group (effective after logging in again)" "$USER")" sudo gpasswd -a "$USER" i2c
    fi
    $changed || nothing_to_do "$(t "the services are already enabled")"
}
