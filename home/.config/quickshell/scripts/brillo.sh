#!/bin/sh
# Brightness of a monitor. Used by Hyprland's keys, the OSD and Settings.
#   brillo.sh get [MONITOR]          → current percentage (a number)
#   brillo.sh set VALUE [MONITOR]    → VALUE: 60%, 5%+, 5%-
# MONITOR is Hyprland's name (eDP-1, DP-9…); if omitted, the focused one.
#
# Internal panel (eDP): backlight with brightnessctl. There are several backlights
# (amdgpu_bl1 real, nvidia_0 fake depending on the GPU mode); the one of the GPU
# the eDP is connected to is used.
# External monitors: DDC/CI with ddcutil (VCP 0x10 = brightness). The i2c bus (per
# DRM connector) and the maximum value are cached so it is fast.

case "$1" in
    get) mon=$2 ;;
    set) mon=$3 ;;
    *)   echo "uso: $0 get [MONITOR] | set VALOR [MONITOR]" >&2; exit 1 ;;
esac
[ -n "$mon" ] || mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
cache="${XDG_RUNTIME_DIR:-/tmp}/brillo-$mon"

backlight() {
    for c in /sys/class/drm/card*-eDP-*; do
        [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
        gpu=$(readlink -f "$c/device" | sed 's|/drm/card[0-9]*$||')
        for b in /sys/class/backlight/*; do
            case "$(readlink -f "$b/device")" in "$gpu"*) basename "$b"; return ;; esac
        done
    done
    ls /sys/class/backlight | head -1
}

ddc_bus() {
    [ -s "$cache.bus" ] && { cat "$cache.bus"; return; }
    bus=$(ddcutil detect --terse 2>/dev/null | awk -v m="$mon" '
        /I2C bus:/ { split($NF, a, "-"); b = a[2] }
        /DRM[_ ]connector:/ { sub(/^card[0-9]+-/, "", $NF); if ($NF == m) { print b; exit } }')
    [ -n "$bus" ] && echo "$bus" > "$cache.bus"
    echo "$bus"
}

# Pantalla interna
case "$mon" in
    eDP-*)
        d=$(backlight)
        if [ "$1" = get ]; then brightnessctl -d "$d" -m | cut -d, -f4 | tr -d '%'
        else brightnessctl -d "$d" -q -n1 set "$2"; fi
        exit ;;
esac

# Monitor externo
command -v ddcutil >/dev/null || { echo "ddcutil no instalado" >&2; exit 1; }
bus=$(ddc_bus)
[ -n "$bus" ] || { echo "sin DDC/CI para $mon" >&2; exit 1; }
ddc="ddcutil --bus $bus --sleep-multiplier 0.1 --skip-ddc-checks"

leer() {   # cur and max; the maximum is cached
    set -- $($ddc getvcp 10 --terse 2>/dev/null)
    [ -n "$4" ] || exit 1
    cur=$4; max=$5
    echo "$max" > "$cache.max"
}

if [ "$1" = get ]; then
    leer; echo $(( cur * 100 / max )); exit
fi

v=$(echo "$2" | tr -d '%+-')
case "$2" in
    *+) leer; n=$(( cur * 100 / max + v )) ;;
    *-) leer; n=$(( cur * 100 / max - v )) ;;
    *)  n=$v; max=$(cat "$cache.max" 2>/dev/null); [ -n "$max" ] || leer ;;
esac
[ "$n" -lt 0 ] && n=0
[ "$n" -gt 100 ] && n=100
$ddc --noverify setvcp 10 $(( n * max / 100 ))
