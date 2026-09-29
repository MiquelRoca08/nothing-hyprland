#!/usr/bin/env bash
# Dotfiles installer. It goes through the modules in instalar/ in order (10-paquetes, 20-aur…):
# each one explains what it does and, before each action, shows the command and asks
#   y (or Enter) yes · n no: skip to the next module · yall yes to all · q quit
# It can be run again at any time: each module only does what is missing (after a git pull too).
#
#   ./install.sh                 every module
#   ./install.sh aur enlaces     only those (by name, without the number)
#   ./install.sh --lang es       in Spanish (default: $LANG; en or es)
#   ./install.sh -h              this help and the module list
#
# New module: a file instalar/NN-name.sh with TITULO, DESCRIPCION (one line each, in English, through
# t) and a function modulo() that does each action with «paso "what it does" command…»
# (functions in instalar/lib.sh). Texts: t "English" (home/.config/quickshell/i18n/i18n.sh), with
# their Spanish in home/.config/quickshell/i18n/es.js.
cd "$(dirname "$(readlink -f "$0")")" || exit 1
DOT=$PWD
FECHA=$(date +%Y%m%d-%H%M%S)
# Language: --lang before anything else prints (i18n.sh reads I18N_LANG)
for ((k = 1; k <= $#; k++)); do
    [[ ${!k} == --lang ]] && { k=$((k + 1)); export I18N_LANG=${!k}; }
    [[ ${!k} == --lang=* ]] && export I18N_LANG=${!k#--lang=}
done
source instalar/lib.sh

MODULOS=(instalar/[0-9][0-9]-*.sh)
nombre() { local b=${1##*/}; b=${b%.sh}; printf '%s' "${b#[0-9][0-9]-}"; }

ayuda() {
    t "Dotfiles installer. It goes through the modules in order: each one explains what it does and, before each action, shows the command and asks." | fold -s -w 96 | sed 's/ *$//'
    echo; echo
    printf '  ./install.sh                 %s\n' "$(t "every module")"
    printf '  ./install.sh aur enlaces     %s\n' "$(t "only those (by name, without the number)")"
    printf '  ./install.sh --lang es       %s\n' "$(t "in Spanish (en or es; by default, the system language)")"
    printf '  ./install.sh -h              %s\n' "$(t "this help")"
    echo
    t "y (or Enter) yes · n no: skip to the next module · yall yes to all · q quit"; echo
    t "It can be run again at any time: each module only does what is missing."; echo
    echo
    echo "$(t "Modules:")"
    local m
    for m in "${MODULOS[@]}"; do
        (source "$m"; printf '\n  %s%-10s%s %s\n' "$B" "$(nombre "$m")" "$N" "$TITULO"
         printf '%s\n' "$DESCRIPCION" | fold -s -w 84 | sed 's/ *$//; s/^/             /')
    done
}

# --- Arguments: none = all; otherwise, the named modules ---
elegidos=() prev=""
for a in "$@"; do
    case $a in
    -h | --help) ayuda; exit 0 ;;
    --lang | --lang=*) ;;
    en | es) [[ $prev == --lang ]] || { t "No module «%s» (./install.sh -h)\n" "$a" >&2; exit 1; } ;;
    -*) t "Unknown option: %s (./install.sh -h)\n" "$a" >&2; exit 1 ;;
    *)
        m=$(printf '%s\n' "${MODULOS[@]}" | while read -r x; do [ "$(nombre "$x")" = "$a" ] && echo "$x"; done)
        [ -n "$m" ] || { t "No module «%s» (./install.sh -h)\n" "$a" >&2; exit 1; }
        elegidos+=("$m") ;;
    esac
    prev=$a
done
((${#elegidos[@]})) && MODULOS=("${elegidos[@]}")

[ "$EUID" -ne 0 ] || { echo "$(t "Run it as your user, without sudo (it asks when needed)")" >&2; exit 1; }
{ : </dev/tty; } 2>/dev/null || { echo "$(t "A terminal is needed: it asks before each action")" >&2; exit 1; }

ESTADO=$(mktemp -d)          # state shared by the modules (yall, initramfs, errors)
trap 'rm -rf "$ESTADO"' EXIT
trap 'echo; echo "$(t "Cancelled.")"; exit 130' INT
export DOT FECHA ESTADO

printf '\n%s%s%s — %s\n' "$B" "$(t "%s's dotfiles" "$USER")" "$N" "$DOT"
printf '%s%s%s\n' "$G" "$(t "%s modules. Before each action you will see the command and can answer y / n (skip module) / yall / q." "${#MODULOS[@]}")" "$N"

hechos=() saltados=() fallidos=()
i=0
for m in "${MODULOS[@]}"; do
    i=$((i + 1))
    rm -f "$ESTADO/errores"
    (
        set -uo pipefail
        source "$m"
        printf '\n%s━━ %d/%d · %s %s━━%s\n' "$R" "$i" "${#MODULOS[@]}" "$TITULO" "$G" "$N"
        printf '%s\n' "$DESCRIPCION" | fold -s -w 96 | sed "s/^/  $G/; s/ *\$/$N/"
        modulo
    )
    rc=$?
    case $rc in
    0) if [ -e "$ESTADO/errores" ]; then fallidos+=("$(nombre "$m")"); else hechos+=("$(nombre "$m")"); fi ;;
    "$SALTAR") saltados+=("$(nombre "$m")"); printf '  %s↷ %s%s\n' "$A" "$(t "Module skipped")" "$N" ;;
    "$SALIR") echo; t "Installation stopped."; echo; break ;;
    *) fallidos+=("$(nombre "$m")"); aviso "$(t "The module ended with an error (code %s)" "$rc")" ;;
    esac
done

printf '\n%s━━ %s %s━━%s\n' "$R" "$(t Summary)" "$G" "$N"
((${#hechos[@]}))    && printf '  %s✓%s %s\n' "$V" "$N" "${hechos[*]}"
((${#saltados[@]}))  && printf '  %s↷%s %s: %s\n' "$A" "$N" "$(t skipped)" "${saltados[*]}"
((${#fallidos[@]}))  && printf '  %s✗%s %s: %s\n' "$R" "$N" "$(t "with errors")" "${fallidos[*]}"
echo "  $(t "Manual steps and details: README.md and docs/")"
