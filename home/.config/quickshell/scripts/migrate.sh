#!/usr/bin/env bash
# Moves the shell's own data to the names it uses since everything moved to English. Config.qml runs
# it on every startup; it only does something when an old name is still there, so it is harmless.
#   ~/.local/share/quickshell/tareas.json   → tasks.json            (Home's tasks)
#   ~/.local/share/quickshell/temas/        → themes/               (installed themes)
#   ~/.local/share/quickshell/tema/         → theme/ (actual.json → current.json)
#   ~/.config/fontconfig/conf.d/51-predeterminada-*.conf → 51-default-*.conf
# and, if the generated theme files do not exist under their new names yet (theme.lua, theme.css),
# it applies the current theme again, which writes them and deletes the old ones.
D="$HOME/.local/share/quickshell"
mv_if() { [[ -e $1 && ! -e $2 ]] && mkdir -p "$(dirname "$2")" && mv "$1" "$2"; }

mv_if "$D/tareas.json" "$D/tasks.json"
mv_if "$D/temas" "$D/themes"
if [[ -d $D/tema ]]; then
    mv_if "$D/tema/actual.json" "$D/theme/current.json"
    mv_if "$D/tema/alacritty.toml" "$D/theme/alacritty.toml"
    rm -f "$D/tema/actual.json" "$D/tema/alacritty.toml"
    rmdir "$D/tema" 2>/dev/null
fi
for f in "$HOME"/.config/fontconfig/conf.d/51-predeterminada-*.conf; do
    [[ -e $f ]] && mv_if "$f" "${f/51-predeterminada-/51-default-}"
done
if [[ -f $D/theme/current.json && ! -f $HOME/.config/hypr/conf/theme.lua ]]; then
    "$(dirname "$(readlink -f "$0")")/theme.sh" apply "$D/theme/current.json" >/dev/null
fi
exit 0
