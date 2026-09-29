# Module: AUR packages (paquetes-aur.txt), with yay
TITULO=$(t "AUR packages")
DESCRIPCION=$(t "Installs with yay the missing packages of paquetes-aur.txt (walker, elephant and its providers, limine-snapper-sync…). If yay is missing, it builds it first from the AUR (yay-bin).")

instalar_yay() {
    local tmp; tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" &&
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    local rc=$?; rm -rf "$tmp"; return $rc
}

modulo() {
    local aur
    command -v yay >/dev/null ||
        paso "$(t "Install yay (AUR helper) from aur.archlinux.org/yay-bin")" instalar_yay
    mapfile -t aur < <(leer "$DOT/paquetes-aur.txt")
    lista_aur      # list with each one's size (installed ones only)
    paso "$(t "Install the %s packages of paquetes-aur.txt" "${#aur[@]}")" yay -S --needed "${aur[@]}"
}
