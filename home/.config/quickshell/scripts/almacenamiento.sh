#!/usr/bin/env bash
# Data for Settings → Storage, as «field|field|…» lines with sizes in bytes:
#   discos     disco|mountpoint|device|type|size|used|free   (no virtual
#              filesystems; subvolumes of the same btrfs show once)
#   limpieza   limpieza|key|bytes   (what can be freed: caches, trash, journal…)
#   paquetes   paquete|name|bytes|aur (1/0)   and   flatpak|name|id|bytes   (the 15 largest)
#   carpetas   carpeta|path|bytes   (what is in ~, largest first; slow: uses du)
LC_ALL=C
export LC_ALL

bytes() {   # «1.5 GiB», «120.0M», «3,2 GB» → bytes
    awk -v s="$*" 'BEGIN {
        gsub(",", ".", s); n = s + 0; u = s; gsub(/[0-9. ]/, "", u); u = toupper(substr(u, 1, 1))
        m = u == "K" ? 1024 : u == "M" ? 1024^2 : u == "G" ? 1024^3 : u == "T" ? 1024^4 : 1
        printf "%.0f\n", n * m }'
}
tam() { du -sb -- "$@" 2>/dev/null | awk '{ s += $1 } END { print s + 0 }'; }

case $1 in
discos)
    df -B1 --output=source,fstype,size,used,avail,target \
        -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs -x ramfs 2>/dev/null |
        awk 'NR > 1 && !visto[$1]++ { print "disco|" $6 "|" $1 "|" $2 "|" $3 "|" $4 "|" $5 }'
    ;;
limpieza)
    echo "limpieza|pacman|$(tam /var/cache/pacman/pkg)"
    echo "limpieza|yay|$(tam "$HOME/.cache/yay")"
    echo "limpieza|cache|$(tam "$HOME/.cache")"
    echo "limpieza|papelera|$(tam "$HOME/.local/share/Trash")"
    j=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ ?[KMGT]' | head -1)
    echo "limpieza|registro|$(bytes "${j:-0}")"
    echo "limpieza|flatpak|$(tam /var/lib/flatpak "$HOME/.local/share/flatpak")"
    if command -v pacman >/dev/null; then
        huerfanos=$(pacman -Qtdq 2>/dev/null)
        if [[ -n $huerfanos ]]; then
            echo "limpieza|huerfanos|$(pacman -Qi $huerfanos 2>/dev/null | awk -F': ' '/^Installed Size/ {
                n = $2 + 0; u = toupper(substr($2, index($2, " ") + 1, 1))
                s += n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) } END { printf "%.0f", s }')|$(wc -w <<<"$huerfanos")"
        else
            echo "limpieza|huerfanos|0|0"
        fi
    fi
    ;;
paquetes)
    if command -v pacman >/dev/null; then
        pacman -Qi 2>/dev/null | awk -F': ' -v aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') " '
            function b(s,  n, u) { n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
                return n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) }
            /^Name/ { n = $2 }
            /^Installed Size/ { printf "paquete|%s|%.0f|%d\n", n, b($2), (index(aur, " " n " ") > 0) }' |
            sort -t'|' -k3,3nr | head -15
    fi
    if command -v flatpak >/dev/null; then
        flatpak list --app --columns=name,application,size 2>/dev/null |
            while IFS=$'\t' read -r n id t; do echo "flatpak|$n|$id|$(bytes "$t")"; done
    fi
    ;;
carpetas)
    shopt -s dotglob nullglob
    du -xsb -- "$HOME"/* 2>/dev/null | sort -rn | head -15 | awk -F'\t' '{ print "carpeta|" $2 "|" $1 }'
    ;;
*)
    echo "uso: $0 discos|limpieza|paquetes|carpetas" >&2; exit 1 ;;
esac
