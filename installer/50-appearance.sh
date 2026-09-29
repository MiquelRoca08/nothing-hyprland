# Module: prompt, theme, cursor, gsettings and user services
TITLE=$(t "Appearance and session")
DESCRIPTION=$(t "Bash prompt (one line in ~/.bashrc), desktop theme colors (Alacritty, walker, GTK and Hyprland borders; outside the repo), fallback cursor XCursor-Pro-Dark (21 MB, downloaded), GTK theme/cursor/font with gsettings, the walker and elephant user services and ~/.config/hypr/xdph.conf (it carries your home folder's path; generated from xdph.conf.template).")

# Cursor: Win11-Fluent-Dark if you have it (private/, not redistributable); otherwise XCursor-Pro-Dark
CURSOR=XCursor-Pro-Dark
[ -f "$HOME/.local/share/icons/Win11-Fluent-Dark/index.theme" ] && CURSOR=Win11-Fluent-Dark

XDPH="$DOT/home/.config/hypr/xdph.conf"
xdph_rendered() { sed "s|@HOME@|$HOME|g" "$XDPH.template"; }
write_xdph() { xdph_rendered >"$XDPH"; }

PROMPT_LINE='[[ -f ~/.config/bash/prompt.sh ]] && . ~/.config/bash/prompt.sh'
add_prompt() { printf '\n# Prompt and colors (dotfiles)\n%s\n' "$PROMPT_LINE" >>"$HOME/.bashrc"; }

download_cursor() {
    mkdir -p "$HOME/.local/share/icons" &&
        curl -fsSL https://github.com/ful1e5/XCursor-pro/releases/download/v2.0.2/XCursor-Pro-Dark.tar.xz |
        tar -xJ -C "$HOME/.local/share/icons"
}

# GTK theme, cursor and UI font (docs/SYSTEM.md, «System theme»)
GSETTINGS=(
    "gtk-theme 'NothingOS'" "color-scheme 'prefer-dark'" "accent-color 'slate'"
    "cursor-theme '$CURSOR'" "cursor-size 32" "font-name 'JetBrainsMono Nerd Font 11'"
)
apply_gsettings() {
    local kv
    for kv in "${GSETTINGS[@]}"; do
        eval "gsettings set org.gnome.desktop.interface $kv" 2>/dev/null ||
            [ "${kv%% *}" = accent-color ] || return    # accent-color does not exist on older GNOME
    done
}
gsettings_pending() {
    local kv
    for kv in "${GSETTINGS[@]}"; do
        [ "$(gsettings get org.gnome.desktop.interface "${kv%% *}" 2>/dev/null)" = "${kv#* }" ] || return 0
    done
    return 1
}

module() {
    local changed=false theme
    if ! grep -qF "$PROMPT_LINE" "$HOME/.bashrc" 2>/dev/null; then
        changed=true; step "$(t "Load the dotfiles prompt from ~/.bashrc")" add_prompt
    fi
    # Theme colors: theme.sh generates them from the current theme (or Nothing the first time)
    if [ ! -f "$HOME/.local/share/quickshell/theme/alacritty.toml" ] || [ ! -f "$DOT/home/.config/hypr/conf/theme.lua" ]; then
        changed=true
        theme="$HOME/.local/share/quickshell/theme/current.json"
        [ -f "$theme" ] || theme="$DOT/home/.config/quickshell/themes/nothing.json"
        if command -v jq >/dev/null; then
            step "$(t "Generate the colors of the «%s» theme" "$(jq -r .name "$theme")")" \
                "$DOT/home/.config/quickshell/scripts/theme.sh" apply "$theme"
        else
            warn "$(t "jq is missing (packages module): without it the theme colors are not generated")"
        fi
    fi
    if [ ! -d "$HOME/.local/share/icons/XCursor-Pro-Dark" ]; then
        changed=true; step "$(t "Download the fallback cursor XCursor-Pro-Dark")" download_cursor
    fi
    if command -v gsettings >/dev/null && gsettings_pending; then
        changed=true; info "gsettings: ${GSETTINGS[*]}"
        step "$(t "Set the NothingOS GTK theme, the %s cursor and the JetBrainsMono font" "$CURSOR")" apply_gsettings
    fi
    if ! systemctl --user is-enabled --quiet elephant.service 2>/dev/null ||
       ! systemctl --user is-enabled --quiet walker.service 2>/dev/null; then
        changed=true
        step "$(t "Enable the walker and elephant user services")" \
            sh -c 'systemctl --user daemon-reload && systemctl --user enable elephant.service walker.service'
    fi
    if [ "$(xdph_rendered)" != "$(cat "$XDPH" 2>/dev/null)" ]; then
        changed=true; step "$(t "Generate ~/.config/hypr/xdph.conf (the shell's screen-share picker)")" write_xdph
    fi
    $changed || nothing_to_do "$(t "prompt, theme, cursor, gsettings, services and xdph.conf are already there")"
}
