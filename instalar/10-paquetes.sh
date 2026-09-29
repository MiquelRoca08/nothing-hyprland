# Module: packages from the official repositories (paquetes.txt)
TITULO=$(t "Packages from the repositories")
DESCRIPCION=$(t "Installs with pacman the missing packages of paquetes.txt (--needed: those already installed are left alone). It uses -Syu, so it also updates the whole system. Names that no longer exist in the repositories are skipped with a warning. First it shows each package with its size and the total.")

modulo() {
    local repos=() faltan=() p
    info "$(t "Checking paquetes.txt…")"
    while read -r p; do
        if pacman -Si "$p" >/dev/null 2>&1; then repos+=("$p"); else faltan+=("$p"); fi
    done < <(leer "$DOT/paquetes.txt")
    ((${#faltan[@]})) && aviso "$(t "Not in the repositories (skipped): %s" "${faltan[*]}")"
    lista_repos     # list with each one's size and the total
    paso "$(t "Install the %s packages of paquetes.txt and update the system" "${#repos[@]}")" \
        sudo pacman -Syu --needed "${repos[@]}"
}
