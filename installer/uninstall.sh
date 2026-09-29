# Module: uninstall (only with «./install.sh uninstall»; not part of a normal run)
TITLE=$(t "Uninstall")
DESCRIPTION=$(t "Undoes the dotfiles in your home folder: removes the links into the repo and puts back the .bak copies of what was there before, stops the walker and elephant services, removes the prompt line from ~/.bashrc, the generated theme files and the GTK settings, and turns off greetd's autologin (or goes back to SDDM). Your settings (settings.json, monitors.lua…) stay in the repo folder, and the installed packages and system files stay too: it says which.")

tilde() { case $1 in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

# Links in $HOME that point into the repo (whatever their target, even if it no longer exists)
repo_links() {
    local l
    find "$HOME/.config" "$HOME/.local" "$HOME/.claude" -maxdepth 4 -type l 2>/dev/null | sort |
        while read -r l; do [[ $(readlink "$l") == "$DOT"/* ]] && echo "$l"; done
}

# remove_links link…: removes them and, if there is a .bak-<date> copy, puts the newest one back
remove_links() {
    local l bak
    for l; do
        rm -f "$l" || return
        bak=$(ls -d "$l".bak-* 2>/dev/null | sort | tail -1)
        if [ -n "$bak" ]; then mv "$bak" "$l" && ok_msg "$(t "%s restored from %s" "$(tilde "$l")" "${bak##*/}")" || return
        else ok_msg "$(t "removed %s" "$(tilde "$l")")"; fi
    done
}

# The theme files theme.sh wrote outside the repo (next to the gtk.css links)
GENERATED=("$HOME/.config/gtk-3.0/theme.css" "$HOME/.config/gtk-4.0/theme.css")

# greetd without [initial_session] (no autologin): the password login stays
no_autologin() {
    sudo awk '/^\[initial_session\]/ { skip = 1; next } /^\[/ { skip = 0 } !skip' /etc/greetd/config.toml \
        | sudo tee /etc/greetd/config.toml.new >/dev/null &&
        sudo mv /etc/greetd/config.toml.new /etc/greetd/config.toml
}

module() {
    local links=() gen=() f
    mapfile -t links < <(repo_links)
    info "$(t "What stays:")"
    info "  · $(t "the repo folder %s, with your settings (settings.json, monitors.lua, autostart-local.lua): delete it when you want" "$DOT")"
    info "  · $(t "the installed packages (packages.txt, packages-aur.txt): remove them with pacman if you want")"
    info "  · $(t "the system files copied to / (greetd, PAM, Limine, mkinitcpio, arch-update…): they keep the system booting")"
    warn "$(t "Hyprland and the shell lose their config at once: log out when it finishes")"

    # 1. User services first (their unit files are links into the repo)
    if systemctl --user is-enabled --quiet walker.service 2>/dev/null || systemctl --user is-enabled --quiet elephant.service 2>/dev/null; then
        step "$(t "Stop and disable the walker and elephant user services")" \
            systemctl --user disable --now walker.service elephant.service
    fi

    # 2. Links (and the copies of what was there before)
    if ((${#links[@]})); then
        info "$(t "Links into the repo:")"; for f in "${links[@]}"; do printf '    %s\n' "$(tilde "$f")"; done
        step "$(t "Remove %s links and put back the .bak copies" "${#links[@]}")" remove_links "${links[@]}"
        systemctl --user daemon-reload 2>/dev/null
    else
        nothing_to_do "$(t "there are no links into the repo")"
    fi

    # 3. Autologin: without the dotfiles nothing would lock the session (before the optional steps:
    #    answering n to one of them skips the rest)
    if grep -q '^\[initial_session\]' /etc/greetd/config.toml 2>/dev/null; then
        step "$(t "Turn off greetd's autologin (it will ask for the password)")" no_autologin
    fi

    # 4. ~/.bashrc, generated files, GTK settings
    if grep -qF '.config/bash/prompt.sh' "$HOME/.bashrc" 2>/dev/null; then
        step "$(t "Remove the prompt line from ~/.bashrc")" \
            sed -i -e '/^# Prompt and colors (dotfiles)$/d' -e '\|\.config/bash/prompt\.sh|d' "$HOME/.bashrc"
    fi
    for f in "${GENERATED[@]}"; do [ -e "$f" ] && gen+=("$f"); done
    ((${#gen[@]})) && step "$(t "Remove the generated theme files")" rm -f "${gen[@]}"
    if command -v gsettings >/dev/null; then
        step "$(t "Reset the GTK theme, cursor, font and color scheme (gsettings)")" \
            sh -c 'for k in gtk-theme cursor-theme font-name color-scheme; do gsettings reset org.gnome.desktop.interface $k; done'
    fi

    # 5. Optional: back to SDDM, and the shell's data
    if systemctl is-enabled --quiet greetd.service 2>/dev/null && systemctl list-unit-files sddm.service >/dev/null 2>&1; then
        step "$(t "Go back to SDDM (disable greetd, enable SDDM)")" \
            sh -c 'sudo systemctl disable greetd.service && sudo systemctl enable sddm.service'
    fi
    if [ -d "$HOME/.local/share/quickshell" ]; then
        info "$(t "~/.local/share/quickshell has the shell's data (applied theme, installed themes, tasks)")"
        step "$(t "Delete ~/.local/share/quickshell and ~/.cache/quickshell")" \
            rm -rf "$HOME/.local/share/quickshell" "$HOME/.cache/quickshell"
    fi
}
