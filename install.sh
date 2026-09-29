#!/usr/bin/env bash
# Dotfiles installer. It goes through the modules in installer/ in order (10-packages, 20-aur…):
# each one explains what it does and, before each action, shows the command and asks
#   y (or Enter) yes · n no: skip to the next module · yall yes to all · q quit
# It can be run again at any time: each module only does what is missing (after a git pull too).
#
#   ./install.sh                 every module
#   ./install.sh aur links        only those (by name, without the number)
#   ./install.sh --lang es       in Spanish (default: $LANG; en or es)
#   ./install.sh -h              this help and the module list
#
# New module: a file installer/NN-name.sh with TITLE, DESCRIPTION (one line each, in English, through
# t) and a function module() that does each action with «step "what it does" command…»
# (functions in installer/lib.sh). Texts: t "English" (home/.config/quickshell/i18n/i18n.sh), with
# their Spanish in home/.config/quickshell/i18n/es.js.
cd "$(dirname "$(readlink -f "$0")")" || exit 1
DOT=$PWD
STAMP=$(date +%Y%m%d-%H%M%S)
# Language: --lang before anything else prints (i18n.sh reads I18N_LANG)
for ((k = 1; k <= $#; k++)); do
    [[ ${!k} == --lang ]] && { k=$((k + 1)); export I18N_LANG=${!k}; }
    [[ ${!k} == --lang=* ]] && export I18N_LANG=${!k#--lang=}
done
source installer/lib.sh

MODULES=(installer/[0-9][0-9]-*.sh)
module_name() { local b=${1##*/}; b=${b%.sh}; printf '%s' "${b#[0-9][0-9]-}"; }

usage() {
    t "Dotfiles installer. It goes through the modules in order: each one explains what it does and, before each action, shows the command and asks." | fold -s -w 96 | sed 's/ *$//'
    echo; echo
    printf '  ./install.sh                 %s\n' "$(t "every module")"
    printf '  ./install.sh aur links        %s\n' "$(t "only those (by name, without the number)")"
    printf '  ./install.sh --lang es       %s\n' "$(t "in Spanish (en or es; by default, the system language)")"
    printf '  ./install.sh -h              %s\n' "$(t "this help")"
    echo
    t "y (or Enter) yes · n no: skip to the next module · yall yes to all · q quit"; echo
    t "It can be run again at any time: each module only does what is missing."; echo
    echo
    echo "$(t "Modules:")"
    local m
    for m in "${MODULES[@]}"; do
        (source "$m"; printf '\n  %s%-10s%s %s\n' "$B" "$(module_name "$m")" "$N" "$TITLE"
         printf '%s\n' "$DESCRIPTION" | fold -s -w 84 | sed 's/ *$//; s/^/             /')
    done
}

# --- Arguments: none = all; otherwise, the named modules ---
chosen=() prev=""
for a in "$@"; do
    case $a in
    -h | --help) usage; exit 0 ;;
    --lang | --lang=*) ;;
    en | es) [[ $prev == --lang ]] || { t "No module «%s» (./install.sh -h)\n" "$a" >&2; exit 1; } ;;
    -*) t "Unknown option: %s (./install.sh -h)\n" "$a" >&2; exit 1 ;;
    *)
        m=$(printf '%s\n' "${MODULES[@]}" | while read -r x; do [ "$(module_name "$x")" = "$a" ] && echo "$x"; done)
        [ -n "$m" ] || { t "No module «%s» (./install.sh -h)\n" "$a" >&2; exit 1; }
        chosen+=("$m") ;;
    esac
    prev=$a
done
((${#chosen[@]})) && MODULES=("${chosen[@]}")

[ "$EUID" -ne 0 ] || { echo "$(t "Run it as your user, without sudo (it asks when needed)")" >&2; exit 1; }
{ : </dev/tty; } 2>/dev/null || { echo "$(t "A terminal is needed: it asks before each action")" >&2; exit 1; }

STATE=$(mktemp -d)          # state shared by the modules (yall, initramfs, errors)
trap 'rm -rf "$STATE"' EXIT
trap 'echo; echo "$(t "Cancelled.")"; exit 130' INT
export DOT STAMP STATE

printf '\n%s%s%s — %s\n' "$B" "$(t "%s's dotfiles" "$USER")" "$N" "$DOT"
printf '%s%s%s\n' "$G" "$(t "%s modules. Before each action you will see the command and can answer y / n (skip module) / yall / q." "${#MODULES[@]}")" "$N"

done_list=() skipped_list=() failed_list=()
i=0
for m in "${MODULES[@]}"; do
    i=$((i + 1))
    rm -f "$STATE/errors"
    (
        set -uo pipefail
        source "$m"
        printf '\n%s━━ %d/%d · %s %s━━%s\n' "$R" "$i" "${#MODULES[@]}" "$TITLE" "$G" "$N"
        printf '%s\n' "$DESCRIPTION" | fold -s -w 96 | sed "s/^/  $G/; s/ *\$/$N/"
        module
    )
    rc=$?
    case $rc in
    0) if [ -e "$STATE/errors" ]; then failed_list+=("$(module_name "$m")"); else done_list+=("$(module_name "$m")"); fi ;;
    "$SKIP") skipped_list+=("$(module_name "$m")"); printf '  %s↷ %s%s\n' "$A" "$(t "Module skipped")" "$N" ;;
    "$QUIT") echo; t "Installation stopped."; echo; break ;;
    *) failed_list+=("$(module_name "$m")"); warn "$(t "The module ended with an error (code %s)" "$rc")" ;;
    esac
done

printf '\n%s━━ %s %s━━%s\n' "$R" "$(t Summary)" "$G" "$N"
((${#done_list[@]}))    && printf '  %s✓%s %s\n' "$V" "$N" "${done_list[*]}"
((${#skipped_list[@]}))  && printf '  %s↷%s %s: %s\n' "$A" "$N" "$(t skipped)" "${skipped_list[*]}"
((${#failed_list[@]}))  && printf '  %s✗%s %s: %s\n' "$R" "$N" "$(t "with errors")" "${failed_list[*]}"
echo "  $(t "Manual steps and details: README.md and docs/")"
