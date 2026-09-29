# Module: symlinks from home/ into $HOME (enlaces.txt)
TITULO=$(t "Dotfiles links")
DESCRIPCION=$(t "Links each path of enlaces.txt from the repo's home/ into your home folder (so the repo's changes show at once). Whatever already exists and is not a link is saved as <path>.bak-<date>. It only touches paths that do not point to the repo yet. What is not in the public repo (e.g. the Win11-Fluent cursor, which cannot be redistributed) is taken from privado/home/ if you have it; otherwise it is skipped.")

# Source of a path: the repo's home/ or, if missing, privado/home/ (your own files, not in git)
origen() {
    if [ -e "$DOT/home/$1" ]; then echo "$DOT/home/$1"
    elif [ -e "$DOT/privado/home/$1" ]; then echo "$DOT/privado/home/$1"; fi
}

enlazar() {   # enlazar path…
    local p src dst
    for p; do
        src=$(origen "$p"); dst="$HOME/$p"
        mkdir -p "$(dirname "$dst")" || return
        if [ -e "$dst" ] && [ ! -L "$dst" ]; then mv "$dst" "$dst.bak-$FECHA" && info "$(t "backup: %s" "~/$p.bak-$FECHA")" || return; fi
        ln -sfn "$src" "$dst" && hecho "~/$p" || return
    done
    fc-cache -f >/dev/null 2>&1 || true    # in case there are new fonts (Doto)
}

modulo() {
    local p pend=()
    while read -r p; do
        src=$(origen "$p")
        [ -n "$src" ] || { info "$(t "skipping %s (not in the repo nor in privado/)" "~/$p")"; continue; }
        [ "$(readlink "$HOME/$p")" = "$src" ] || pend+=("$p")
    done < <(grep -vE '^#|^$' "$DOT/enlaces.txt")
    ((${#pend[@]})) || { nada "$(t "all the links are fine")"; return; }
    info "$(t "To link:")"; printf '    ~/%s\n' "${pend[@]}"
    paso "$(t "Link %s paths" "${#pend[@]}")" enlazar "${pend[@]}"
}
