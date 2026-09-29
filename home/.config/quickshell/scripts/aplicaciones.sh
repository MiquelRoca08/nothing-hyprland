#!/usr/bin/env bash
# Data for Settings → Apps, as «field|field|…» lines (sizes in bytes):
#   instaladas       app|name|icon|origin|id|bytes|file.desktop
#                    origin: repos | aur | flatpak | webapp | tui | otro;  id: the package, the Flatpak id
#                    or, for web apps and TUIs, the .desktop name (for «webapp/tui quitar»)
#                    Only those shown in the launcher (no NoDisplay or Hidden).
#   paquetes         paquete|name|bytes|aur (1/0)|explicit (1/0)|description   (all: pacman -Qi)
#   buscar-repos T   res|repos|name|version|installed (1/0)|description   (the first 40)
#   buscar-aur T     res|aur|…  (by popularity)
#   buscar-flatpak T res|flatpak|id|version|installed|description|name
LC_ALL=C
export LC_ALL
TAB=$'\t'

# pacman sizes («12.50 MiB») to bytes, inside awk
AWK_BYTES='function b(s,  n, u) { n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
    return n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) }'

# Every .desktop at once: file, Name (localized if present), Icon, Type, NoDisplay, Hidden, X-Creado-Por
# (from the [Desktop Entry] section), separated by \037 (not a tab: read merges consecutive
# empty fields when the separator is whitespace)
leer_desktop() {
    awk -F= '
        function nombre() { return v["Name[es_ES]"] != "" ? v["Name[es_ES]"] : v["Name[es]"] != "" ? v["Name[es]"] : v["Name"] }
        function sale() { if (f) print f S nombre() S v["Icon"] S v["Type"] S v["NoDisplay"] S v["Hidden"] S v["X-Creado-Por"] }
        BEGIN { S = "\037" }
        FNR == 1 { sale(); f = FILENAME; split("", v); s = 0 }
        /^\[/ { s = ($0 == "[Desktop Entry]"); next }
        s && !($1 in v) { k = $1; sub(/^[^=]*=/, ""); v[k] = $0 }
        END { sale() }' "$@"
}

instaladas() {
    local dirs=("$HOME/.local/share/applications" /usr/share/applications
                "$HOME/.local/share/flatpak/exports/share/applications" /var/lib/flatpak/exports/share/applications)
    [[ -n $APPS_DIRS ]] && read -ra dirs <<<"$APPS_DIRS"   # for tests
    local f d nombre icono tipo nd oculto creado origen id sistema=() visto=" " archivos=()
    declare -A lineas
    shopt -s nullglob
    for d in "${dirs[@]}"; do archivos+=("$d"/*.desktop); done
    ((${#archivos[@]})) || return 0
    while IFS=$'\037' read -r f nombre icono tipo nd oculto creado; do
        [[ $nd == true || $oculto == true || $tipo != Application ]] && continue
        id=$(basename "$f" .desktop)
        # A user .desktop with the same name overrides the system one (it comes first in the list)
        [[ $visto == *" $id "* ]] && continue
        visto+="$id "
        case $creado in
        webapp) origen=webapp ;;
        tui) origen=tui ;;
        *)
            if [[ $f == */flatpak/exports/* ]]; then origen=flatpak
            elif [[ $f == */usr/share/applications/* ]]; then origen=sistema; sistema+=("$f")
            else origen=otro; fi ;;
        esac
        lineas[$f]="${nombre//|//}|$icono|$origen|$id"
    done < <(leer_desktop "${archivos[@]}")
    # Package of each system .desktop (a single pacman call) and their sizes
    declare -A dueno tam
    if ((${#sistema[@]})) && command -v pacman >/dev/null; then
        while read -r f p; do dueno[$f]=$p; done < <(pacman -Qo "${sistema[@]}" 2>/dev/null |
            sed -nE 's/^(.*) is owned by ([^ ]+) .*/\1 \2/p')
        local aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') "
        while IFS='|' read -r p t; do tam[$p]=$t; done < <(pacman -Qi $(printf '%s\n' "${dueno[@]}" | sort -u) 2>/dev/null |
            awk -F': ' "$AWK_BYTES"' /^Name/ { n = $2 } /^Installed Size/ { printf "%s|%.0f\n", n, b($2) }')
    fi
    declare -A fpt
    if command -v flatpak >/dev/null; then
        while IFS=$TAB read -r id t; do
            fpt[$id]=$(awk -v s="$t" 'BEGIN { gsub(",", ".", s); n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
                printf "%.0f", n * (u == "K" ? 1000 : u == "M" ? 1e6 : u == "G" ? 1e9 : 1) }')
        done < <(flatpak list --app --columns=application,size 2>/dev/null)
    fi
    for f in "${!lineas[@]}"; do
        IFS='|' read -r nombre icono origen id <<<"${lineas[$f]}"
        bytes=0
        case $origen in
        sistema)
            p=${dueno[$f]}
            if [[ -n $p ]]; then
                id=$p; bytes=${tam[$p]:-0}; origen=repos; [[ $aur == *" $p "* ]] && origen=aur
            else origen=otro; fi ;;
        flatpak) bytes=${fpt[$id]:-0} ;;
        esac
        echo "app|$nombre|$icono|$origen|$id|$bytes|$f"
    done
}

# res|origin|name|version|installed|description  from the output of pacman -Ss / yay -Ss
busqueda() {
    awk -v o="$1" '
        /^[^ ]/ { if (n) print r; split($1, a, "/"); n = a[2]; v = $2; i = ($0 ~ /\[[Ii]nstal/) ? 1 : 0; d = ""
                  r = "res|" o "|" n "|" v "|" i "|"; next }
        /^    / { sub(/^ +/, ""); gsub(/\|/, "/"); r = r $0 }
        END { if (n) print r }' | head -"${2:-40}"
}

case $1 in
instaladas) instaladas ;;
paquetes)
    command -v pacman >/dev/null || exit 0
    pacman -Qi 2>/dev/null | awk -F': ' -v aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') " "$AWK_BYTES"'
        /^Name/ { n = $2 } /^Description/ { d = $2; gsub(/\|/, "/", d) } /^Installed Size/ { t = b($2) }
        /^Install Reason/ { printf "paquete|%s|%.0f|%d|%d|%s\n", n, t, (index(aur, " " n " ") > 0), ($2 ~ /^Explicitly/), d }'
    ;;
buscar-repos) [[ -n $2 ]] && pacman -Ss -- "$2" 2>/dev/null | busqueda repos ;;
buscar-aur) [[ -n $2 ]] && command -v yay >/dev/null && yay -Ssa --sortby popularity --topdown -- "$2" 2>/dev/null | busqueda aur ;;
buscar-flatpak)
    [[ -n $2 ]] && command -v flatpak >/dev/null || exit 0
    instalados=" $(flatpak list --app --columns=application 2>/dev/null | tr '\n' ' ') "
    flatpak search --columns=name,application,version,description -- "$2" 2>/dev/null | head -40 |
        while IFS=$TAB read -r n id v d; do
            [[ -n $id && $id == *.* ]] || continue
            i=0; [[ $instalados == *" $id "* ]] && i=1
            echo "res|flatpak|$id|$v|$i|${d//|//}|$n"
        done
    ;;
*) echo "uso: $0 instaladas | paquetes | buscar-repos|buscar-aur|buscar-flatpak <texto>" >&2; exit 1 ;;
esac
