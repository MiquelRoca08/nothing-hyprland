#!/usr/bin/env bash
# Data and actions for Settings → Personalization → Fonts, as «field|field|…» lines:
#   instaladas        fuente|family|origin|package|files|bytes|folder|mono (1/0)
#                     and at the end  defecto|sans-serif family|monospace family
#                     origin: repos | aur | usuario (~/.local/share/fonts or another folder in ~) | otro
#                     One line per family (fc-list); the package comes from pacman -Qo.
#   buscar T          res|repos|name|version|installed|description   and   res|aur|…
#                     Font packages only (ttf-*, otf-*, noto-fonts*, *-fonts…).
#   instalar-archivo  picks .ttf/.otf/.woff/.zip with zenity and copies them to ~/.local/share/fonts
#   quitar-usuario F  deletes families F (only their files inside ~) and rebuilds the cache
#   predeterminada F mono size
#                     the default font: with mono=1, the monospace one (monospace in fontconfig and
#                     GTK's monospace-font-name); otherwise the text one (sans-serif and font-name).
#                     fontconfig: ~/.config/fontconfig/conf.d/51-predeterminada-<tipo>.conf
LC_ALL=C
export LC_ALL
DIR="$HOME/.local/share/fonts"
PATRON='^(ttf-|otf-|woff2?-|noto-fonts|adobe-source-|gnu-free-fonts|.*-fonts?$|.*-font-)'

buscar() {   # $1 origin (repos|aur) — pacman/yay -Ss output on stdin
    awk -v o="$1" -v pat="$PATRON" '
        /^[^ ]/ { if (n ~ pat) print r; split($1, a, "/"); n = a[2]; v = $2; i = ($0 ~ /\[[Ii]nstal/) ? 1 : 0
                  r = "res|" o "|" n "|" v "|" i "|"; next }
        /^    / { sub(/^ +/, ""); gsub(/\|/, "/"); r = r $0 }
        END { if (n ~ pat) print r }' | head -40
}

case $1 in
instaladas)
    # family \t file \t bytes, one line per file
    fc-list --format '%{family[0]}\t%{file}\n' 2>/dev/null | sort -u | while IFS=$'\t' read -r fam f; do
        printf '%s\t%s\t%s\n' "$fam" "$f" "$(stat -c %s "$f" 2>/dev/null || echo 0)"
    done > "${TMPDIR:-/tmp}/fuentes.$$"
    # Package of each system file (a single pacman call)
    declare -A dueno
    if command -v pacman >/dev/null; then
        while read -r f p; do dueno[$f]=$p; done < <(cut -f2 "${TMPDIR:-/tmp}/fuentes.$$" | grep -v "^$HOME/" |
            xargs -r -d '\n' pacman -Qo 2>/dev/null | sed -nE 's/^(.*) is owned by ([^ ]+) .*/\1 \2/p')
        aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') "
    fi
    while IFS=$'\t' read -r fam f b; do
        if [[ $f == "$HOME"/* ]]; then o=usuario; p=""
        elif [[ -n ${dueno[$f]} ]]; then p=${dueno[$f]}; o=repos; [[ ${aur:-} == *" $p "* ]] && o=aur
        else o=otro; p=""; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$fam" "$o" "$p" "$b" "${f%/*}"
    done < "${TMPDIR:-/tmp}/fuentes.$$" |
        awk -F'\t' -v monos="$(fc-list :spacing=mono --format '%{family[0]}\n' 2>/dev/null | sort -u | tr '\n' '\t')" '
            BEGIN { split(monos, m, "\t"); for (i in m) mono[m[i]] = 1 }
            { k = $1; if (!(k in o)) { o[k] = $2; p[k] = $3; d[k] = $5; orden[++n] = k } a[k]++; b[k] += $4 }
            END { for (i = 1; i <= n; i++) { k = orden[i]; x = k; gsub(/\|/, "/", x)
                  printf "fuente|%s|%s|%s|%d|%.0f|%s|%d\n", x, o[k], p[k], a[k], b[k], d[k], (k in mono) } }'
    rm -f "${TMPDIR:-/tmp}/fuentes.$$"
    echo "defecto|$(fc-match -f '%{family[0]}' sans-serif 2>/dev/null)|$(fc-match -f '%{family[0]}' monospace 2>/dev/null)"
    ;;
predeterminada)
    fam=$2 mono=$3 tam=${4:-11}
    [[ -n $fam ]] || exit 1
    tipo=sans-serif clave=font-name
    [[ $mono == 1 ]] && tipo=monospace clave=monospace-font-name
    d="$HOME/.config/fontconfig/conf.d"
    mkdir -p "$d"
    x=${fam//&/&amp;}; x=${x//</&lt;}; x=${x//>/&gt;}
    cat >"$d/51-predeterminada-$tipo.conf" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Fuente $tipo por defecto: la pone Ajustes → Personalización → Fuentes -->
<fontconfig>
  <alias binding="strong">
    <family>$tipo</family>
    <prefer><family>$x</family></prefer>
  </alias>
</fontconfig>
XML
    command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface "$clave" "$fam $tam"
    fc-cache -f >/dev/null 2>&1
    echo "defecto|$(fc-match -f '%{family[0]}' sans-serif)|$(fc-match -f '%{family[0]}' monospace)"
    ;;
buscar)
    [[ -n $2 ]] || exit 0
    pacman -Ss -- "$2" 2>/dev/null | buscar repos
    command -v yay >/dev/null && yay -Ssa --sortby popularity --topdown -- "$2" 2>/dev/null | buscar aur
    ;;
instalar-archivo)
    archivos=$(zenity --file-selection --multiple --separator=$'\n' --title='Instalar fuentes' \
        --file-filter='Fuentes | *.ttf *.otf *.woff *.woff2 *.TTF *.OTF *.zip *.ZIP' 2>/dev/null) || exit 1
    mkdir -p "$DIR"
    n=0
    while read -r f; do
        [[ -f $f ]] || continue
        case ${f,,} in
        *.zip) d="$DIR/$(basename "${f%.*}")"; mkdir -p "$d"
               unzip -oqj "$f" '*.ttf' '*.otf' '*.TTF' '*.OTF' -d "$d" 2>/dev/null && n=$((n + 1)) ;;
        *) cp -f "$f" "$DIR/" && n=$((n + 1)) ;;
        esac
    done <<<"$archivos"
    fc-cache -f "$DIR" >/dev/null 2>&1
    echo "instaladas|$n"
    ;;
quitar-usuario)
    shift
    for fam in "$@"; do
        fc-list --format '%{file}\n' ":family=$fam" 2>/dev/null | while read -r f; do
            [[ $f == "$HOME"/* ]] && rm -f -- "$f"
        done
    done
    find "$DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
    fc-cache -f "$DIR" >/dev/null 2>&1
    ;;
*) echo "uso: $0 instaladas | buscar <texto> | instalar-archivo | quitar-usuario <familia>…" >&2; exit 1 ;;
esac
