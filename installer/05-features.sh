# Module: optional features (features.txt) you can leave out
TITLE=$(t "Optional features")
DESCRIPTION=$(t "Lists the features the desktop does not need (Bluetooth, printers, face unlock, ASUS tools, Flatpak…) and lets you leave out the ones you do not want: their packages are not installed and, if they already are, they are removed (not the ones other programs need); their services are not enabled and their system files are not copied. The choice is saved in excluded-features.txt (not in git) and the other modules follow it; run it again to bring one back.")

installed_of() {   # installed_of id: its installed packages
    local p; for p in $(feature_field "$1" 3); do pacman -Qq "$p" >/dev/null 2>&1 && echo "$p"; done
}

# remove_feature id: disables its services and removes its installed packages, except the ones that
# a package outside the feature still needs
remove_feature() {
    local id=$1 s p req pkgs=() keep=() own
    own=" $(feature_field "$id" 3) "
    for s in $(feature_field "$id" 4); do
        systemctl is-enabled --quiet "$s" 2>/dev/null || systemctl is-active --quiet "$s" 2>/dev/null || continue
        sudo systemctl disable --now "$s" && ok_msg "$(t "disabled %s" "$s")" || return
    done
    for p in $(installed_of "$id"); do
        req=$(LC_ALL=C pacman -Qi "$p" | sed -n 's/^Required By *: *//p')
        req=$(for r in $req; do [ "$r" = None ] || [[ $own == *" $r "* ]] || echo "$r"; done)
        if [ -n "$req" ]; then keep+=("$p ($(echo $req))"); else pkgs+=("$p"); fi
    done
    ((${#keep[@]})) && info "$(t "kept, other programs need them: %s" "${keep[*]}")"
    ((${#pkgs[@]})) || return 0
    sudo pacman -Rns --noconfirm "${pkgs[@]}"
}

# Colors of the menu's package picker (~/.local/bin/packages): white and greys, red for removing
FZF_COLORS='fg:#b0b0b0,fg+:#ffffff,bg+:#161616,hl:#ffffff,hl+:#ffffff,info:#6e6e6e,prompt:#ffffff,pointer:#d71921,marker:#d71921,spinner:#6e6e6e,header:#6e6e6e,border:#2e2e2e,label:#6e6e6e'

# pick_fzf: like the menu's Install/Remove (fzf, Tab marks several, details below). Prints the ids
# to leave out; returns 1 if cancelled (Esc: the current choice is kept)
pick_fzf() {
    local dir="$STATE/features" id p s n i=1 binds="load:" out
    mkdir -p "$dir"
    {
        printf '%s\n\n' "$(t "Leave nothing out: keep every feature")"
        t "Unmark everything (Tab) and accept this line."; echo
    } >"$dir/-"
    {
        printf -- '-\t%s\n' "$(t "Leave nothing out: keep every feature")"
        for id in "${ids[@]}"; do
            i=$((i + 1))
            is_excluded "$id" && binds+="pos($i)+toggle+"
            n=$(installed_of "$id" | wc -l)
            printf '%s\t%-56s\t%s\n' "$id" "$(t "$(feature_field "$id" 2)")" \
                "$( ((n)) && t installed || t "not installed")"
            {
                printf '%s\n\n%s\n' "$(t "$(feature_field "$id" 2)")" "$(t "Packages:")"
                for p in $(feature_field "$id" 3); do
                    if pacman -Qq "$p" >/dev/null 2>&1; then printf '  ✓ %s\n' "$p"; else printf '  · %s\n' "$p"; fi
                done
                s=$(feature_field "$id" 4); [ -n "$s" ] && printf '%s\n%s\n' "$(t "Services:")" "$(printf '  %s\n' $s)"
                s=$(feature_field "$id" 5); [ -n "$s" ] && printf '%s\n%s\n' "$(t "System files:")" "$(printf '  %s\n' $s)"
            } >"$dir/$id"
        done
    } >"$dir/.list"
    out=$(fzf --multi --reverse --prompt '  ' --delimiter '\t' --with-nth 2,3 --accept-nth 1 \
        --header "$(t "Mark with Tab what you want to leave out · Enter accepts · Esc keeps the current choice")" \
        --preview "cat $dir/{1}" --preview-label "$(t "alt-p: details · alt-j/k: scroll")" --preview-label-pos bottom \
        --preview-window 'down:45%:wrap' --bind 'alt-p:toggle-preview' --bind 'alt-k:preview-up,alt-j:preview-down' \
        --bind "${binds}first" --color "$FZF_COLORS" <"$dir/.list") || return 1
    printf '%s\n' "$out" | grep -vx -- '-' || true
}

module() {
    local ids=() id i n mark state line out chosen=() new
    mapfile -t ids < <(feature_ids)
    echo
    for i in "${!ids[@]}"; do
        id=${ids[i]}
        n=$(installed_of "$id" | wc -l)
        if is_excluded "$id"; then mark="${R}✗${N}"; else mark="${V}✓${N}"; fi
        if ((n)); then state="$(t installed)"; else state="${G}$(t "not installed")${N}"; fi
        printf '  %2d) %s %-56s %s\n' "$((i + 1))" "$mark" "$(t "$(feature_field "$id" 2)")" "$state"
    done
    echo
    if [ -e "$STATE/yall" ]; then
        info "$(t "yes to all: the current choice is kept")"
    elif command -v fzf >/dev/null; then
        if out=$(pick_fzf); then mapfile -t chosen <<<"$out"; else mapfile -t chosen < <(excluded_ids); fi
    else
        # Without fzf (a new install: the packages module comes later), a numbered list
        info "$(t "✗ = left out. Type the numbers of the ones you do NOT want (e.g. «1 3»): that replaces the choice.")"
        info "$(t "Enter keeps it as it is; «none» brings them all back; q quits.")"
        while :; do
            printf '  %s> %s' "$B" "$N"
            read -r line </dev/tty || exit $QUIT
            case ${line,,} in
            "") chosen=(); mapfile -t chosen < <(excluded_ids); break ;;
            q) exit $QUIT ;;
            none | ninguno | ninguna) chosen=(); break ;;
            esac
            chosen=()
            for i in ${line//,/ }; do
                if [[ $i =~ ^[0-9]+$ ]] && ((i >= 1 && i <= ${#ids[@]})); then chosen+=("${ids[i - 1]}")
                else chosen=(); info "$(t "«%s» is not a number of the list" "$i")"; continue 2; fi
            done
            break
        done
    fi
    if [ ! -e "$STATE/yall" ]; then
        new=$(printf '%s\n' "${chosen[@]}" | sed '/^$/d' | sort -u)
        if [ "$new" != "$(excluded_ids | sort -u)" ]; then
            if [ -n "$new" ]; then printf '%s\n' "$new" >"$EXCLUDED"; else rm -f "$EXCLUDED"; fi
            ok_msg "$(t "Saved in excluded-features.txt")"
        fi
    fi
    # Left out but still installed: remove them
    local did=false
    for id in $(excluded_ids); do
        [ -n "$(installed_of "$id")" ] || continue
        did=true
        step "$(t "Remove «%s»: %s" "$(t "$(feature_field "$id" 2)")" "$(installed_of "$id" | tr '\n' ' ')")" remove_feature "$id"
    done
    $did || nothing_to_do "$(t "nothing left out is installed")"
    is_excluded ddc && id -nG | grep -qw i2c && info "$(t "The i2c group stays; remove yourself with: sudo gpasswd -d %s i2c" "$USER")"
}
