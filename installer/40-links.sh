# Module: symlinks from home/ into $HOME (links.txt)
TITLE=$(t "Dotfiles links")
DESCRIPTION=$(t "Links each path of links.txt from the repo's home/ into your home folder (so the repo's changes show at once). Whatever already exists and is not a link is saved as <path>.bak-<date>. It only touches paths that do not point to the repo yet. What is not in the public repo (e.g. the Win11-Fluent cursor, which cannot be redistributed) is taken from private/home/ if you have it; otherwise it is skipped. It also removes the links left by files the repo renamed or deleted.")

# Source of a path: the repo's home/ or, if missing, private/home/ (your own files, not in git)
source_of() {
    if [ -e "$DOT/home/$1" ]; then echo "$DOT/home/$1"
    elif [ -e "$DOT/private/home/$1" ]; then echo "$DOT/private/home/$1"; fi
}

# Links from earlier versions of the repo (files renamed to English or removed): if they still point
# into the repo and their target is gone, they are removed
OLD_LINKS=(
    .local/bin/bloquear .local/bin/captura .local/bin/grabar .local/bin/paquetes
    .local/bin/compartir-pantalla .local/bin/menu-atajos .local/bin/menu-atras
    .config/nvim/plugin/portapapeles.lua .claude/skills/sistema Documents/SYSTEM.md
)
stale_links() {
    local p t
    for p in "${OLD_LINKS[@]}"; do
        [ -L "$HOME/$p" ] || continue
        t=$(readlink "$HOME/$p")
        [[ $t == "$DOT"/* && ! -e $t ]] && echo "$p"
    done
}
remove_links() { local p; for p; do rm -f "$HOME/$p" && ok_msg "$(t "removed %s" "~/$p")"; done; }

link_paths() {   # link_paths path…
    local p src dst
    for p; do
        src=$(source_of "$p"); dst="$HOME/$p"
        mkdir -p "$(dirname "$dst")" || return
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then mv "$dst" "$dst.bak-$STAMP" && info "$(t "backup: %s" "~/$p.bak-$STAMP")" || return; fi
        ln -sfn "$src" "$dst" && ok_msg "~/$p" || return
    done
    fc-cache -f >/dev/null 2>&1 || true    # in case there are new fonts (Doto)
}

module() {
    local p pending=() stale=()
    # privado/ was renamed to private/: move your own files if you still have the old folder
    if [ -d "$DOT/privado" ] && [ ! -e "$DOT/private" ]; then
        step "$(t "Rename privado/ to private/ (your own files, not in git)")" mv "$DOT/privado" "$DOT/private"
    fi
    mapfile -t stale < <(stale_links)
    if ((${#stale[@]})); then
        info "$(t "Links to files the repo no longer has:")"; printf '    ~/%s\n' "${stale[@]}"
        step "$(t "Remove %s old links" "${#stale[@]}")" remove_links "${stale[@]}"
    fi
    while read -r p; do
        src=$(source_of "$p")
        [ -n "$src" ] || { info "$(t "skipping %s (not in the repo nor in private/)" "~/$p")"; continue; }
        [ "$(readlink "$HOME/$p")" = "$src" ] || pending+=("$p")
    done < <(grep -vE '^#|^$' "$DOT/links.txt")
    ((${#pending[@]})) || { nothing_to_do "$(t "all the links are fine")"; return; }
    info "$(t "To link:")"; printf '    ~/%s\n' "${pending[@]}"
    step "$(t "Link %s paths" "${#pending[@]}")" link_paths "${pending[@]}"
}
