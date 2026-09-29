# Module: symlinks from home/ into $HOME (links.txt)
TITLE=$(t "Dotfiles links")
DESCRIPTION=$(t "Links each path of links.txt from the repo's home/ into your home folder (so the repo's changes show at once). Whatever already exists and is not a link is saved as <path>.bak-<date>. It only touches paths that do not point to the repo yet. What is not in the public repo (e.g. the Win11-Fluent cursor, which cannot be redistributed) is taken from private/home/ if you have it; otherwise it is skipped. It also removes the links left by files the repo renamed or deleted. Your monitors and autostart apps are kept: before replacing ~/.config/hypr they are copied from your current config into conf/monitors.lua and conf/autostart-local.lua (yours, not in git).")

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

# Your own Hyprland pieces, not in git (conf/monitors.lua and conf/autostart-local.lua): imported
# from the config ~/.config/hypr had before (installer/hypr-import.py) or, for the monitors, from the
# running session; without either, a rule that fits any monitor
HYPR_CONF="$DOT/home/.config/hypr/conf"
hypr_import() {   # hypr_import [old config folder]
    local out kind a b c
    out=$(python3 "$DOT/installer/hypr-import.py" ${1:+--from "$1"} "$HYPR_CONF") || return
    while IFS='|' read -r kind a b c; do
        case $kind:$a in
        monitors:config)   ok_msg "$(t "conf/monitors.lua: %s monitor rules from your previous config" "$b")" ;;
        monitors:session)  ok_msg "$(t "conf/monitors.lua: %s monitors as they are now" "$b")" ;;
        monitors:fallback) ok_msg "$(t "conf/monitors.lua: every monitor with its preferred mode and automatic scale (adjust it in Settings → Displays)")" ;;
        autostart:written) ok_msg "$(t "conf/autostart-local.lua: %s autostart apps kept, %s commented out (this desktop already does it)" "$b" "$c")" ;;
        autostart:none)    info "$(t "Your previous config had no autostart apps")" ;;
        esac
    done <<<"$out"
}
# The config to import: ~/.config/hypr if it exists and is not this repo's yet
old_hypr() {
    local d="$HOME/.config/hypr"
    [ -e "$d" ] || return
    [ "$(readlink -f "$d")" = "$(readlink -f "$DOT/home/.config/hypr")" ] && return
    readlink -f "$d"
}

module() {
    local p old did= pending=() stale=()
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
    if ((${#pending[@]})); then
        info "$(t "To link:")"; printf '    ~/%s\n' "${pending[@]}"
        # Before ~/.config/hypr is replaced (and Hyprland reloads with the repo's config)
        old=$(old_hypr)
        if [ -n "$old" ] && command -v python3 >/dev/null &&
           { [ ! -e "$HYPR_CONF/monitors.lua" ] || [ ! -e "$HYPR_CONF/autostart-local.lua" ]; }; then
            step "$(t "Keep the monitors and autostart apps of your current Hyprland config (%s)" "$old")" \
                hypr_import "$old"
        fi
        step "$(t "Link %s paths" "${#pending[@]}")" link_paths "${pending[@]}"
        did=1
    fi
    if [ ! -e "$HYPR_CONF/monitors.lua" ]; then
        if command -v python3 >/dev/null; then
            step "$(t "Create conf/monitors.lua for this machine's monitors")" hypr_import
            did=1
        else
            warn "$(t "python is missing (packages module): conf/monitors.lua is not created; Hyprland uses every monitor's preferred mode")"
        fi
    fi
    # The repo's git hooks (.githooks/): reload Hyprland after a git pull that changes its config
    if [ "$(git -C "$DOT" config core.hooksPath)" != .githooks ]; then
        step "$(t "Reload Hyprland after each git pull that changes its config (the repo's git hooks)")" \
            git -C "$DOT" config core.hooksPath .githooks
        did=1
    fi
    [ -n "$did" ] || nothing_to_do "$(t "all the links are fine")"
}
