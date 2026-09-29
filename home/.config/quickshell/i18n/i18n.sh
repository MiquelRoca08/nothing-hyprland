# Interface language for shell scripts, with the same dictionary as the shell (i18n/es.js) and
# the same source: the system locale, LANG in /etc/locale.conf (Settings → System → Language sets
# it; read from the file, not from the environment, so a change applies at once). Spanish if it is
# es_*, English otherwise. Source it and write the texts in English:
#   t "Done"                    → the text in the interface language
#   t "%s packages" "$n"        → printf-style values (%s), after translating
# Only es.js entries whose Spanish has no «%1»-style placeholders make sense here: write the
# script's texts with %s and add them to es.js like any other.
_i18n_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
_i18n_lang() {
    local l
    l=$(sed -n 's/^LANG=//p' /etc/locale.conf 2>/dev/null | tr -d '"')
    [[ -n $l ]] || l=${LANG:-}
    [[ $l == es* ]] && echo es || echo en
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
