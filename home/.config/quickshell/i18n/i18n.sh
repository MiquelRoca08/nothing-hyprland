# Interface language for shell scripts, with the same dictionary as the shell (i18n/es.js) and
# the same setting (Settings → System → Language: "language" in settings.json; "auto" follows
# $LANG). Source it and write the texts in English:
#   t "Done"                    → the text in the interface language
#   t "%s packages" "$n"        → printf-style values (%s), after translating
# I18N_HOME (default $HOME): whose settings.json to read (arch-update runs as root).
# Only es.js entries whose Spanish has no «%1»-style placeholders make sense here: write the
# script's texts with %s and add them to es.js like any other.
_i18n_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
_i18n_lang() {
    local f="${I18N_HOME:-$HOME}/.config/quickshell/settings.json" l=auto
    command -v jq >/dev/null && [[ -f $f ]] && l=$(jq -r '.language // "auto"' "$f" 2>/dev/null)
    case $l in
    en | es) echo "$l" ;;
    *) [[ ${LC_ALL:-${LC_MESSAGES:-${LANG:-}}} == es* ]] && echo es || echo en ;;
    esac
}
I18N_LANG=${I18N_LANG:-$(_i18n_lang)}   # preset I18N_LANG=en|es to force it (install.sh --lang)
declare -gA I18N=()
if [[ $I18N_LANG == es && -f $_i18n_dir/es.js ]]; then
    while IFS=$'\t' read -r _k _v; do I18N[$_k]=$_v; done < <(
        sed -nE 's/^    "((\\.|[^"\\])*)": "((\\.|[^"\\])*)",$/\1\t\3/p' "$_i18n_dir/es.js" | sed 's/\\"/"/g')
    unset _k _v
fi
t() {
    local s=$1
    [[ -n $s ]] && s=${I18N[$s]:-$s}
    shift
    if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi
}
