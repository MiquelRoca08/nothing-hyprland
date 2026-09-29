# Module: packages from the official repositories (packages.txt)
TITLE=$(t "Packages from the repositories")
DESCRIPTION=$(t "Installs with pacman the missing packages of packages.txt (--needed: those already installed are left alone). It uses -Syu, so it also updates the whole system. Names that no longer exist in the repositories are skipped with a warning. First it shows each package with its size and the total.")

module() {
    local repos=() missing=() p
    info "$(t "Checking packages.txt…")"
    while read -r p; do
        if pacman -Si "$p" >/dev/null 2>&1; then repos+=("$p"); else missing+=("$p"); fi
    done < <(read_packages "$DOT/packages.txt")
    ((${#missing[@]})) && warn "$(t "Not in the repositories (skipped): %s" "${missing[*]}")"
    list_repo_sizes     # list with each one's size and the total
    step "$(t "Install the %s packages of packages.txt and update the system" "${#repos[@]}")" \
        sudo pacman -Syu --needed "${repos[@]}"
}
