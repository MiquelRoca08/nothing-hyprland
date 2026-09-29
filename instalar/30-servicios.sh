# Module: system services and groups
TITULO=$(t "System services")
DESCRIPCION=$(t "Enables the services the shell and the menus use: network (NetworkManager), Bluetooth, power profiles, printers (cups) and network discovery (avahi). The rest start by themselves through D-Bus. Adds your user to the i2c group (brightness of external monitors through DDC/CI).")

modulo() {
    local s hay=false
    for s in NetworkManager.service bluetooth.service power-profiles-daemon.service cups.socket avahi-daemon.service; do
        systemctl list-unit-files "$s" >/dev/null 2>&1 || continue
        systemctl is-enabled --quiet "$s" 2>/dev/null && continue
        hay=true
        paso "$(t "Enable %s at boot" "$s")" sudo systemctl enable "$s"
    done
    if getent group i2c >/dev/null && ! id -nG | grep -qw i2c; then
        hay=true
        paso "$(t "Add %s to the i2c group (effective after logging in again)" "$USER")" sudo gpasswd -a "$USER" i2c
    fi
    $hay || nada "$(t "the services are already enabled")"
}
