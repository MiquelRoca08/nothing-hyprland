# Module: login with greetd
TITULO=$(t "Login")
DESCRIPCION=$(t "Autologin with greetd (/etc/greetd/config.toml, from the system module) instead of SDDM: the session starts by itself and locks at once with the shell's lock screen.")

modulo() {
    local hay=false
    if systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        hay=true; paso "$(t "Disable SDDM")" sudo systemctl disable sddm.service
    fi
    if systemctl list-unit-files greetd.service >/dev/null 2>&1 && ! systemctl is-enabled --quiet greetd.service; then
        hay=true; paso "$(t "Enable greetd at boot")" sudo systemctl enable greetd.service
    fi
    $hay || nada "$(t "greetd is already enabled")"
}
