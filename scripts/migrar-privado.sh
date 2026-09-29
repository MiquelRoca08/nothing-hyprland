#!/usr/bin/env bash
# Once, on the machine where the repo used to be private: saves into privado/ (not in git, in
# .gitignore) what the public repo no longer carries, taking it from the git history:
#   privado/system/etc/fstab                          this machine's fstab (disk UUIDs)
#   privado/home/.local/share/icons/Win11-Fluent-Dark cursor (not redistributable)
#   home/.config/quickshell/settings.json             your shell settings (stays where it is, now outside git)
# install.sh links whatever is in privado/home/ just like home/. Nothing is deleted.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."

# Last commit that still had each path
antes() { git log --format=%H -1 --diff-filter=D -- "$1" | xargs -r -I{} git rev-parse '{}^'; }

sacar() {   # sacar path-in-repo destination
    local c; c=$(antes "$1")
    [ -n "$c" ] || { echo "  no está en el historial: $1"; return; }
    if [ -e "$2" ]; then echo "  ya existe, no se toca: $2"; return; fi
    mkdir -p "$(dirname "$2")"
    if [ "$(git cat-file -t "$c:$1")" = tree ]; then
        mkdir -p "$2" && git archive "$c" "$1" | tar -x --strip-components="$(tr -cd / <<<"$1" | wc -c)" -C "$(dirname "$2")"
    else
        git show "$c:$1" >"$2"
    fi
    echo "  ✓ $2"
}

echo "Guardando en privado/ lo que ya no está en el repo:"
sacar system/etc/fstab privado/system/etc/fstab
sacar home/.local/share/icons/Win11-Fluent-Dark privado/home/.local/share/icons/Win11-Fluent-Dark
# Settings: if you have a newer copy (the one from before the pull), use it
# (it wins even if the shell created a default one when the file disappeared)
if [ -f privado/settings.json.antes ]; then
    mv -f privado/settings.json.antes home/.config/quickshell/settings.json && echo "  ✓ settings.json (tu copia)"
else
    sacar home/.config/quickshell/settings.json home/.config/quickshell/settings.json
fi
echo "Hecho. Ahora ./install.sh enlaces aspecto (vuelve a enlazar el cursor y genera xdph.conf)."
