#!/usr/bin/env bash
# The system locale is the interface language (Settings → System → Language). The shell (I18n.qml),
# the menu and the scripts (i18n/i18n.sh) read LANG from /etc/locale.conf, so changing it here
# changes all of them at once (walker is restarted: walker-config translates its config); other apps
# pick it up after logging out and back in.
#   locale.sh set en|es   run in a terminal (it asks for the password): generates the locale if it
#                         is missing (/etc/locale.gen + locale-gen) and sets LANG with localectl,
#                         keeping the LC_* lines of /etc/locale.conf
source "$HOME/.config/quickshell/i18n/i18n.sh" 2>/dev/null ||
    t() { local s=$1; shift; if (($#)); then printf -- "$s" "$@"; else printf '%s' "$s"; fi; }

[[ $1 == set && ($2 == en || $2 == es) ]] || { echo "usage: $0 set en|es" >&2; exit 1; }
lang=$2
pref=es_ES
[[ $lang == en ]] && pref=en_US

current=$(sed -n 's/^LANG=//p' /etc/locale.conf 2>/dev/null | tr -d '"')
if [[ ${current%%_*} == "$lang" ]]; then
    echo "$(t "The system language is already %s." "$current")"
    exit 0
fi

# A locale of that language that is already generated (the preferred region first); otherwise the
# preferred one is generated
mapfile -t generated < <(locale -a 2>/dev/null | grep -iE "^${lang}_[A-Z]+\.utf-?8$")
target=
for l in "${generated[@]}"; do
    [[ ${l%%.*} == "$pref" ]] && { target=$pref.UTF-8; break; }
done
[[ -z $target && ${#generated[@]} -gt 0 ]] && target=${generated[0]%%.*}.UTF-8
if [[ -z $target ]]; then
    target=$pref.UTF-8
    echo "$(t "Generating the %s locale…" "$target")"
    sudo sed -i -E "s/^#[[:space:]]*(${pref}\.UTF-8 UTF-8)/\1/" /etc/locale.gen || exit 1
    grep -qE "^${pref}\.UTF-8 UTF-8" /etc/locale.gen ||
        echo "$pref.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen >/dev/null || exit 1
    sudo locale-gen || exit 1
fi

# localectl replaces the whole file: the LC_* lines are passed again so they are kept
mapfile -t keep < <(grep -E '^LC_[A-Z_]+=' /etc/locale.conf 2>/dev/null | tr -d '"')
sudo localectl set-locale "LANG=$target" "${keep[@]}" || exit 1
# The user services (walker, elephant…) and what systemd starts from now on
systemctl --user set-environment "LANG=$target" 2>/dev/null
# walker reads its config once: restart it (walker.service rewrites config.toml in the new language)
"$HOME/.local/bin/walker-restart" 2>/dev/null
echo "$(t "System language: %s. The shell and the menu change now; other apps, after logging out and back in." "$target")"
