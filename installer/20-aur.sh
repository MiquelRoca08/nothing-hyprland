# Module: AUR packages (packages-aur.txt), with yay
TITLE=$(t "AUR packages")
DESCRIPTION=$(t "Installs with yay the missing packages of packages-aur.txt (walker, elephant and its providers, limine-snapper-sync…). If yay is missing, it builds it first from the AUR (yay-bin).")

install_yay() {
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    local rc=$?; rm -rf "$tmp"; return $rc
}

module() {
    local aur
    command -v yay >/dev/null ||
        step "$(t "Install yay (AUR helper) from aur.archlinux.org/yay-bin")" install_yay
    mapfile -t aur < <(read_packages "$DOT/packages-aur.txt")
    list_aur_sizes      # list with each one's size (installed ones only)
    step "$(t "Install the %s packages of packages-aur.txt" "${#aur[@]}")" yay -S --needed "${aur[@]}"
}
