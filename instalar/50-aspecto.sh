# Module: prompt, theme, cursor, gsettings and user services
TITULO=$(t "Appearance and session")
DESCRIPCION=$(t "Bash prompt (one line in ~/.bashrc), desktop theme colors (Alacritty, walker, GTK and Hyprland borders; outside the repo), fallback cursor XCursor-Pro-Dark (21 MB, downloaded), GTK theme/cursor/font with gsettings, the walker and elephant user services and ~/.config/hypr/xdph.conf (it carries your home folder's path; generated from xdph.conf.plantilla).")

# Cursor: Win11-Fluent-Dark if you have it (privado/, not redistributable); otherwise XCursor-Pro-Dark
CURSOR=XCursor-Pro-Dark
[ -f "$HOME/.local/share/icons/Win11-Fluent-Dark/index.theme" ] && CURSOR=Win11-Fluent-Dark

XDPH="$DOT/home/.config/hypr/xdph.conf"
xdph_generado() { sed "s|@HOME@|$HOME|g" "$XDPH.plantilla"; }
generar_xdph() { xdph_generado >"$XDPH"; }

LINEA='[[ -f ~/.config/bash/prompt.sh ]] && . ~/.config/bash/prompt.sh'
anadir_prompt() { printf '\n# Prompt and colors (dotfiles)\n%s\n' "$LINEA" >>"$HOME/.bashrc"; }

bajar_cursor() {
    mkdir -p "$HOME/.local/share/icons" &&
        curl -fsSL https://github.com/ful1e5/XCursor-pro/releases/download/v2.0.2/XCursor-Pro-Dark.tar.xz |
        tar -xJ -C "$HOME/.local/share/icons"
}

# GTK theme, cursor and UI font (docs/SYSTEM.md, «System theme»)
GSETTINGS=(
    "gtk-theme 'NothingOS'" "color-scheme 'prefer-dark'" "accent-color 'slate'"
    "cursor-theme '$CURSOR'" "cursor-size 32" "font-name 'JetBrainsMono Nerd Font 11'"
)
aplicar_gsettings() {
    local kv
    for kv in "${GSETTINGS[@]}"; do
        eval "gsettings set org.gnome.desktop.interface $kv" 2>/dev/null ||
            [ "${kv%% *}" = accent-color ] || return    # accent-color does not exist on older GNOME
    done
}
gsettings_pendientes() {
    local kv
    for kv in "${GSETTINGS[@]}"; do
        [ "$(gsettings get org.gnome.desktop.interface "${kv%% *}" 2>/dev/null)" = "${kv#* }" ] || return 0
    done
    return 1
}

modulo() {
    local hay=false tema
    if ! grep -qF "$LINEA" "$HOME/.bashrc" 2>/dev/null; then
        hay=true; paso "$(t "Load the dotfiles prompt from ~/.bashrc")" anadir_prompt
    fi
    # Theme colors: tema.sh generates them from the current theme (or Nothing the first time)
    if [ ! -f "$HOME/.local/share/quickshell/tema/alacritty.toml" ] || [ ! -f "$DOT/home/.config/hypr/conf/tema.lua" ]; then
        hay=true
        tema="$HOME/.local/share/quickshell/tema/actual.json"
        [ -f "$tema" ] || tema="$DOT/home/.config/quickshell/temas/nothing.json"
        if command -v jq >/dev/null; then
            paso "$(t "Generate the colors of the «%s» theme" "$(jq -r .name "$tema")")" \
                "$DOT/home/.config/quickshell/scripts/tema.sh" aplicar "$tema"
        else
            aviso "$(t "jq is missing (packages module): without it the theme colors are not generated")"
        fi
    fi
    if [ ! -d "$HOME/.local/share/icons/XCursor-Pro-Dark" ]; then
        hay=true; paso "$(t "Download the fallback cursor XCursor-Pro-Dark")" bajar_cursor
    fi
    if command -v gsettings >/dev/null && gsettings_pendientes; then
        hay=true; info "gsettings: ${GSETTINGS[*]}"
        paso "$(t "Set the NothingOS GTK theme, the %s cursor and the JetBrainsMono font" "$CURSOR")" aplicar_gsettings
    fi
    if ! systemctl --user is-enabled --quiet elephant.service 2>/dev/null ||
       ! systemctl --user is-enabled --quiet walker.service 2>/dev/null; then
        hay=true
        paso "$(t "Enable the walker and elephant user services")" \
            sh -c 'systemctl --user daemon-reload && systemctl --user enable elephant.service walker.service'
    fi
    if [ "$(xdph_generado)" != "$(cat "$XDPH" 2>/dev/null)" ]; then
        hay=true; paso "$(t "Generate ~/.config/hypr/xdph.conf (the shell's screen-share picker)")" generar_xdph
    fi
    $hay || nada "$(t "prompt, theme, cursor, gsettings, services and xdph.conf are already there")"
}
