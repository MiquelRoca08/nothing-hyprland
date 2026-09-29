# Module: login with greetd
TITLE=$(t "Login")
DESCRIPTION=$(t "Autologin with greetd (/etc/greetd/config.toml, from the system module) instead of SDDM: the session starts by itself and locks at once with the shell's lock screen.")

module() {
    local changed=false
    if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        changed=true; step "$(t "Disable SDDM")" sudo systemctl disable sddm.service
    fi
    if systemctl list-unit-files greetd.service >/dev/null 2>&1 && ! systemctl is-enabled --quiet greetd.service; then
        changed=true; step "$(t "Enable greetd at boot")" sudo systemctl enable greetd.service
    fi
    $changed || nothing_to_do "$(t "greetd is already enabled")"
}
