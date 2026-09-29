#!/usr/bin/env bash
# Data for Settings → Storage, as «field|field|…» lines with sizes in bytes:
#   disks     disk|mountpoint|device|type|size|used|free   (no virtual
#             filesystems; subvolumes of the same btrfs show once)
#   cleanup   cleanup|key|bytes   (what can be freed: pacman, yay, cache, trash, journal, flatpak;
#             orphans also carries how many: cleanup|orphans|bytes|count)
#   packages  package|name|bytes|aur (1/0)   and   flatpak|name|id|bytes   (the 15 largest)
#   folders   folder|path|bytes   (what is in ~, largest first; slow: uses du)
LC_ALL=C
export LC_ALL

bytes() {   # «1.5 GiB», «120.0M», «3,2 GB» → bytes
    awk -v s="$*" 'BEGIN {
        gsub(",", ".", s); n = s + 0; u = s; gsub(/[0-9. ]/, "", u); u = toupper(substr(u, 1, 1))
        m = u == "K" ? 1024 : u == "M" ? 1024^2 : u == "G" ? 1024^3 : u == "T" ? 1024^4 : 1
        printf "%.0f\n", n * m }'
}
size_of() { du -sb -- "$@" 2>/dev/null | awk '{ s += $1 } END { print s + 0 }'; }

case $1 in
disks)
    df -B1 --output=source,fstype,size,used,avail,target \
        -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs -x ramfs 2>/dev/null |
        awk 'NR > 1 && !seen[$1]++ { print "disk|" $6 "|" $1 "|" $2 "|" $3 "|" $4 "|" $5 }'
    ;;
cleanup)
    echo "cleanup|pacman|$(size_of /var/cache/pacman/pkg)"
    echo "cleanup|yay|$(size_of "$HOME/.cache/yay")"
    echo "cleanup|cache|$(size_of "$HOME/.cache")"
    echo "cleanup|trash|$(size_of "$HOME/.local/share/Trash")"
    j=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+ ?[KMGT]' | head -1)
    echo "cleanup|journal|$(bytes "${j:-0}")"
    echo "cleanup|flatpak|$(size_of /var/lib/flatpak "$HOME/.local/share/flatpak")"
    if command -v pacman >/dev/null; then
        orphans=$(pacman -Qtdq 2>/dev/null)
        if [[ -n $orphans ]]; then
            echo "cleanup|orphans|$(pacman -Qi $orphans 2>/dev/null | awk -F': ' '/^Installed Size/ {
                n = $2 + 0; u = toupper(substr($2, index($2, " ") + 1, 1))
                s += n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) } END { printf "%.0f", s }')|$(wc -w <<<"$orphans")"
        else
            echo "cleanup|orphans|0|0"
        fi
    fi
    ;;
packages)
    if command -v pacman >/dev/null; then
        pacman -Qi 2>/dev/null | awk -F': ' -v aur=" $(pacman -Qmq 2>/dev/null | tr '\n' ' ') " '
            function b(s,  n, u) { n = s + 0; u = toupper(substr(s, index(s, " ") + 1, 1))
                return n * (u == "K" ? 1024 : u == "M" ? 1048576 : u == "G" ? 1073741824 : 1) }
            /^Name/ { n = $2 }
            /^Installed Size/ { printf "package|%s|%.0f|%d\n", n, b($2), (index(aur, " " n " ") > 0) }' |
            sort -t'|' -k3,3nr | head -15
    fi
    if command -v flatpak >/dev/null; then
        flatpak list --app --columns=name,application,size 2>/dev/null |
            while IFS=$'\t' read -r n id s; do echo "flatpak|$n|$id|$(bytes "$s")"; done
    fi
    ;;
folders)
    shopt -s dotglob nullglob
    du -xsb -- "$HOME"/* 2>/dev/null | sort -rn | head -15 | awk -F'\t' '{ print "folder|" $2 "|" $1 }'
    ;;
*)
    echo "usage: $0 disks|cleanup|packages|folders" >&2; exit 1 ;;
esac
