#!/usr/bin/env bash
# Data for Settings → Apps, as «field|field|…» lines (sizes in bytes):
#   installed          app|name|icon|origin|id|bytes|file.desktop
#                      origin: repos | aur | flatpak | webapp | tui | manual;  id: the package, the
#                      Flatpak id or, for web apps and TUIs, the .desktop name (for «webapp/tui remove»)
#                      Only those shown in the launcher (no NoDisplay or Hidden). The name is the
#                      one for the interface language (Name[xx]) if the .desktop has it.
#   packages           package|name|bytes|aur (1/0)|explicit (1/0)|description   (all: pacman -Qi)
#   search-repos T     res|repos|name|version|installed (1/0)|description   (the first 40)
#   search-aur T       res|aur|…  (by popularity)
#   search-flatpak T   res|flatpak|id|version|installed|description|name
source "$(dirname "$(readlink -f "$0")")/../i18n/i18n.sh" 2>/dev/null || I18N_LANG=en
LC_ALL=C
export LC_ALL
TAB=$'\t'

# pacman sizes («12.50 MiB») to bytes, inside awk
AWK_BYTES='function b(s,  n, u) { n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
    return n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) }'

# Every .desktop at once: file, Name (in the interface language if present), Icon, Type, NoDisplay,
# Hidden, X-Created-By (or X-Creado-Por, from older versions) — from the [Desktop Entry] section,
# separated by \037 (not a tab: read merges consecutive empty fields when the separator is whitespace)
read_desktop_files() {
    awk -F= -v lang="$I18N_LANG" '
        function name() { return v["Name[" lang "_" toupper(lang) "]"] != "" ? v["Name[" lang "_" toupper(lang) "]"] \
                               : v["Name[" lang "]"] != "" ? v["Name[" lang "]"] : v["Name"] }
        function emit() { if (f) print f S name() S v["Icon"] S v["Type"] S v["NoDisplay"] S v["Hidden"] \
                                       S (v["X-Created-By"] != "" ? v["X-Created-By"] : v["X-Creado-Por"]) }
        BEGIN { S = "\037" }
        FNR == 1 { emit(); f = FILENAME; split("", v); s = 0 }
        /^\[/ { s = ($0 == "[Desktop Entry]"); next }
        s && !($1 in v) { k = $1; sub(/^[^=]*=/, ""); v[k] = $0 }
        END { emit() }' "$@"
}

installed() {
    local dirs=("$HOME/.local/share/applications" /usr/share/applications
                "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications)
    [[ -n $APPS_DIRS ]] && read -ra dirs <<<"$APPS_DIRS"   # for tests
    local f d name icon type nodisplay hidden created_by origin id system=() seen=" " files=()
    declare -A rows
    shopt -s nullglob
    for d in "${dirs[@]}"; do files+=("$d"/*.desktop); done
    ((${#files[@]})) || return 0
    while IFS=$'\037' read -r f name icon type nodisplay hidden created_by; do
        [[ $nodisplay == true || $hidden == true || $type != Application ]] && continue
        id=$(basename "$f" .desktop)
        # A user .desktop with the same name overrides the system one (it comes first in the list)
        [[ $seen == *" $id "* ]] && continue
        seen+="$id "
        case $created_by in
        webapp) origin=webapp ;;
        tui) origin=tui ;;
        *)
            if [[ $f == */flatpak/exports/* ]]; then origin=flatpak
            elif [[ $f == */usr/share/applications/* ]]; then origin=system; system+=("$f")
            else origin=manual; fi ;;
        esac
        rows[$f]="${name//|//}|$icon|$origin|$id"
    done < <(read_desktop_files "${files[@]}")
    # Package of each system .desktop (a single pacman call) and their sizes
    declare -A owner size
    if ((${#system[@]})) && command -v pacman >/dev/null; then
        while read -r f p; do owner[$f]=$p; done < <(pacman -Qo "${system[@]}" 2>/dev/null |
            sed -nE 's/^(.*) is owned by ([^ ]+) .*/\1 \2/p')
        local aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') "
        while IFS='|' read -r p s; do size[$p]=$s; done < <(pacman -Qi $(printf '%s\n' "${owner[@]}" | sort -u) 2>/dev/null |
            awk -F': ' "$AWK_BYTES"' /^Name/ { n = $2 } /^Installed Size/ { printf "%s|%.0f\n", n, b($2) }')
    fi
    declare -A flatpak_size
    if command -v flatpak >/dev/null; then
        while IFS=$TAB read -r id s; do
            flatpak_size[$id]=$(awk -v s="$s" 'BEGIN { gsub(",", ".", s); n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
                printf "%.0f", n * (u == "K" ? 1000 : u == "M" ? 1e6 : u == "G" ? 1e9 : 1) }')
        done < <(flatpak list --app --columns=application,size 2>/dev/null)
    fi
    for f in "${!rows[@]}"; do
        IFS='|' read -r name icon origin id <<<"${rows[$f]}"
        bytes=0
        case $origin in
        system)
            p=${owner[$f]}
            if [[ -n $p ]]; then
                id=$p; bytes=${size[$p]:-0}; origin=repos; [[ $aur == *" $p "* ]] && origin=aur
            else origin=manual; fi ;;
        flatpak) bytes=${flatpak_size[$id]:-0} ;;
        esac
        echo "app|$name|$icon|$origin|$id|$bytes|$f"
    done
}

# res|origin|name|version|installed|description  from the output of pacman -Ss / yay -Ss
search_results() {
    awk -v o="$1" '
        /^[^ ]/ { if (n) print r; split($1, a, "/"); n = a[2]; v = $2; i = ($0 ~ /\[[Ii]nstal/) ? 1 : 0; d = ""
                  r = "res|" o "|" n "|" v "|" i "|"; next }
        /^    / { sub(/^ +/, ""); gsub(/\|/, "/"); r = r $0 }
        END { if (n) print r }' | head -"${2:-40}"
}

case $1 in
installed) installed ;;
packages)
    command -v pacman >/dev/null || exit 0
    pacman -Qi 2>/dev/null | awk -F': ' -v aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') " "$AWK_BYTES"'
        /^Name/ { n = $2 } /^Description/ { d = $2; gsub(/\|/, "/", d) } /^Installed Size/ { s = b($2) }
        /^Install Reason/ { printf "package|%s|%.0f|%d|%d|%s\n", n, s, (index(aur, " " n " ") > 0), ($2 ~ /^Explicitly/), d }'
    ;;
search-repos) [[ -n $2 ]] && pacman -Ss -- "$2" 2>/dev/null | search_results repos ;;
search-aur) [[ -n $2 ]] && command -v yay >/dev/null && yay -Ssa --sortby popularity --topdown -- "$2" 2>/dev/null | search_results aur ;;
search-flatpak)
    [[ -n $2 ]] && command -v flatpak >/dev/null || exit 0
    installed_ids=" $(flatpak list --app --columns=application 2>/dev/null | tr '\n' ' ') "
    flatpak search --columns=name,application,version,description -- "$2" 2>/dev/null | head -40 |
        while IFS=$TAB read -r n id v d; do
            [[ -n $id && $id == *.* ]] || continue
            i=0; [[ $installed_ids == *" $id "* ]] && i=1
            echo "res|flatpak|$id|$v|$i|${d//|//}|$n"
        done
    ;;
*) echo "usage: $0 installed | packages | search-repos|search-aur|search-flatpak <text>" >&2; exit 1 ;;
esac
