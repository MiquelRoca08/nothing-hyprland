#!/usr/bin/env bash
# Data and actions for Settings → Personalization → Fonts, as «field|field|…» lines:
#   installed         font|family|origin|package|files|bytes|folder|mono (1/0)
#                     and at the end  default|sans-serif family|monospace family
#                     origin: repos | aur | user (~/.local/share/fonts or another folder in ~) | other
#                     One line per family (fc-list); the package comes from pacman -Qo.
#   search T          res|repos|name|version|installed|description   and   res|aur|…
#                     Font packages only (ttf-*, otf-*, noto-fonts*, *-fonts…).
#   install-file      picks .ttf/.otf/.woff/.zip with zenity and copies them to ~/.local/share/fonts
#   remove-user F     deletes families F (only their files inside ~) and rebuilds the cache
#   set-default F mono size
#                     the default font: with mono=1, the monospace one (monospace in fontconfig and
#                     GTK's monospace-font-name); otherwise the text one (sans-serif and font-name).
#                     fontconfig: ~/.config/fontconfig/conf.d/51-default-<kind>.conf
source "$(dirname "$(readlink -f "$0")")/../i18n/i18n.sh" 2>/dev/null || t() { printf '%s' "$1"; }
LC_ALL=C
export LC_ALL
DIR="$HOME/.local/share/fonts"
PATTERN='^(ttf-|otf-|woff2?-|noto-fonts|adobe-source-|gnu-free-fonts|.*-fonts?$|.*-font-)'

search_results() {   # $1 origin (repos|aur) — pacman/yay -Ss output on stdin
    awk -v o="$1" -v pat="$PATTERN" '
        /^[^ ]/ { if (n ~ pat) print r; split($1, a, "/"); n = a[2]; v = $2; i = ($0 ~ /\[[Ii]nstal/) ? 1 : 0
                  r = "res|" o "|" n "|" v "|" i "|"; next }
        /^    / { sub(/^ +/, ""); gsub(/\|/, "/"); r = r $0 }
        END { if (n ~ pat) print r }' | head -40
}

case $1 in
installed)
    # family \t file \t bytes, one line per file
    fc-list --format '%{family[0]}\t%{file}\n' 2>/dev/null | sort -u | while IFS=$'\t' read -r fam f; do
        printf '%s\t%s\t%s\n' "$fam" "$f" "$(stat -c %s "$f" 2>/dev/null || echo 0)"
    done > "${TMPDIR:-/tmp}/fonts.$$"
    # Package of each system file (a single pacman call)
    declare -A owner
    if command -v pacman >/dev/null; then
        while read -r f p; do owner[$f]=$p; done < <(cut -f2 "${TMPDIR:-/tmp}/fonts.$$" | grep -v "^$HOME/" |
            xargs -r -d '\n' pacman -Qo 2>/dev/null | sed -nE 's/^(.*) is owned by ([^ ]+) .*/\1 \2/p')
        aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') "
    fi
    while IFS=$'\t' read -r fam f b; do
        if [[ $f == "$HOME"/* ]]; then o=user; p=""
        elif [[ -n ${owner[$f]} ]]; then p=${owner[$f]}; o=repos; [[ ${aur:-} == *" $p "* ]] && o=aur
        else o=other; p=""; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$fam" "$o" "$p" "$b" "${f%/*}"
    done < "${TMPDIR:-/tmp}/fonts.$$" |
        awk -F'\t' -v monos="$(fc-list :spacing=mono --format '%{family[0]}\n' 2>/dev/null | sort -u | tr '\n' '\t')" '
            BEGIN { split(monos, m, "\t"); for (i in m) mono[m[i]] = 1 }
            { k = $1; if (!(k in o)) { o[k] = $2; p[k] = $3; d[k] = $5; order[++n] = k } a[k]++; b[k] += $4 }
            END { for (i = 1; i <= n; i++) { k = order[i]; x = k; gsub(/\|/, "/", x)
                  printf "font|%s|%s|%s|%d|%.0f|%s|%d\n", x, o[k], p[k], a[k], b[k], d[k], (k in mono) } }'
    rm -f "${TMPDIR:-/tmp}/fonts.$$"
    echo "default|$(fc-match -f '%{family[0]}' sans-serif 2>/dev/null)|$(fc-match -f '%{family[0]}' monospace 2>/dev/null)"
    ;;
set-default)
    fam=$2 mono=$3 size=${4:-11}
    [[ -n $fam ]] || exit 1
    kind=sans-serif key=font-name
    [[ $mono == 1 ]] && kind=monospace key=monospace-font-name
    d="$HOME/.config/fontconfig/conf.d"
    mkdir -p "$d"
    x=${fam//&/&amp;}; x=${x//</&lt;}; x=${x//>/&gt;}
    rm -f "$d/51-predeterminada-$kind.conf"   # its name before the move to English
    cat >"$d/51-default-$kind.conf" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Default $kind font: set by Settings → Personalization → Fonts -->
<fontconfig>
  <alias binding="strong">
    <family>$kind</family>
    <prefer><family>$x</family></prefer>
  </alias>
</fontconfig>
XML
    command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface "$key" "$fam $size"
    fc-cache -f >/dev/null 2>&1
    echo "default|$(fc-match -f '%{family[0]}' sans-serif)|$(fc-match -f '%{family[0]}' monospace)"
    ;;
search)
    [[ -n $2 ]] || exit 0
    pacman -Ss -- "$2" 2>/dev/null | search_results repos
    command -v yay >/dev/null && yay -Ssa --sortby popularity --topdown -- "$2" 2>/dev/null | search_results aur
    ;;
install-file)
    files=$(zenity --file-selection --multiple --separator=$'\n' --title="$(t "Install fonts")" \
        --file-filter="$(t Fonts) | *.ttf *.otf *.woff *.woff2 *.TTF *.OTF *.zip *.ZIP" 2>/dev/null) || exit 1
    mkdir -p "$DIR"
    n=0
    while read -r f; do
        [[ -f $f ]] || continue
        case ${f,,} in
        *.zip) d="$DIR/$(basename "${f%.*}")"; mkdir -p "$d"
               unzip -oqj "$f" '*.ttf' '*.otf' '*.TTF' '*.OTF' -d "$d" 2>/dev/null && n=$((n + 1)) ;;
        *) cp -f "$f" "$DIR/" && n=$((n + 1)) ;;
        esac
    done <<<"$files"
    fc-cache -f "$DIR" >/dev/null 2>&1
    echo "installed|$n"
    ;;
remove-user)
    shift
    for fam in "$@"; do
        fc-list --format '%{file}\n' ":family=$fam" 2>/dev/null | while read -r f; do
            [[ $f == "$HOME"/* ]] && rm -f -- "$f"
        done
    done
    find "$DIR" -mindepth 1 -type d -empty -delete 2>/dev/null
    fc-cache -f "$DIR" >/dev/null 2>&1
    ;;
*) echo "usage: $0 installed | search <text> | install-file | remove-user <family>… | set-default <family> <mono> <size>" >&2; exit 1 ;;
esac
