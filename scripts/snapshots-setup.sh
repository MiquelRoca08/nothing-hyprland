#!/usr/bin/env bash
#
# Moves the btrfs root to subvolumes (@ and @home) and sets up snapper + limine-snapper-sync
# so the snapshots arch-update creates show up in Limine. It is done in phases:
#
#   sudo ./snapshots-setup.sh phase1   # creates @ and @home, initramfs with overlay, Limine → reboot
#   sudo ./snapshots-setup.sh phase2   # (already in @) snapper, Limine config and arch-update
#        yay -S limine-snapper-sync    # as the user, without sudo
#   sudo ./snapshots-setup.sh phase3   # enables the sync and creates the first snapshot
#   sudo ./snapshots-setup.sh cleanup  # (once everything works) deletes the old root
#
# Until «cleanup», the old root stays intact and Limine has the «Rescue» entry.
set -euo pipefail

SYS="$(cd "$(dirname "$0")/../system" && pwd)"
# This machine's btrfs root partition (filesystem UUID and partition PARTUUID)
ROOT_DEV="$(findmnt -no SOURCE / | sed 's/\[.*//')"
DEV_UUID="$(lsblk -no UUID "$ROOT_DEV")"
ROOT_PARTUUID="$(lsblk -no PARTUUID "$ROOT_DEV")"
TOP="/mnt/btrfs-top"

die() { echo "ERROR: $*" >&2; exit 1; }
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

current_subvol() { findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's/^subvol=//p'; }

phase1() {
    [[ "$(current_subvol)" == "/" ]] || die "the root is no longer the whole volume (subvol=$(current_subvol)); did you already run phase 1?"
    # An earlier interrupted attempt leaves /@ and /@home: they are only copies made
    # by this phase (the current root is the good one), so they are deleted and redone
    for sv in /@ /@home; do
        if [[ -e "$sv" ]]; then
            echo "Deleting $sv from an earlier attempt…"
            btrfs subvolume delete "$sv"
        fi
    done

    step "Initramfs: btrfs-overlayfs hook and UKI without an embedded cmdline (limine.conf sets it)"
    install -Dm644 "$SYS/etc/initcpio/install/btrfs-overlayfs" /etc/initcpio/install/btrfs-overlayfs
    install -Dm644 "$SYS/etc/initcpio/hooks/btrfs-overlayfs" /etc/initcpio/hooks/btrfs-overlayfs
    install -Dm644 "$SYS/etc/mkinitcpio.conf" /etc/mkinitcpio.conf
    install -Dm644 "$SYS/etc/mkinitcpio.d/linux.preset" /etc/mkinitcpio.d/linux.preset
    rm -f /etc/kernel/cmdline
    mkinitcpio -P

    step "Subvolumes @ and @home (snapshots of the current volume; no data is copied)"
    sync
    btrfs subvolume snapshot / /@
    btrfs subvolume snapshot / /@home

    step "@home: only the contents of /home"
    shopt -s dotglob nullglob
    # Without --one-file-system: nested subvolumes (/var/lib/machines…) show up
    # in the copy as empty directories on another device and it would refuse to delete them
    for e in /@home/*; do
        [[ "$e" == /@home/home ]] && continue
        rm -rf -- "$e"
    done
    mv /@home/home/* /@home/
    rmdir /@home/home

    step "@: empty /home (its contents are in @home) and new fstab"
    for e in /@/home/*; do rm -rf -- "$e"; done
    install -Dm644 "$SYS/etc/fstab" /@/etc/fstab
    shopt -u dotglob nullglob

    step "Limine: entry in @, snapshots and «Rescue» (old root)"
    # At the root of the partition (/boot/limine.conf), which is where
    # limine-snapper-sync looks for it; Limine finds it there if there is none in /EFI/BOOT/
    [[ -f /boot/EFI/BOOT/limine.conf ]] && mv /boot/EFI/BOOT/limine.conf /boot/EFI/BOOT/limine.conf.before-snapshots
    install -Dm644 "$SYS/boot/limine.conf" /boot/limine.conf
    install -Dm644 "$SYS/boot/EFI/BOOT/limine-nothing.png" /boot/EFI/BOOT/limine-nothing.png
    cat >> /boot/limine.conf <<EOF

# Temporary: boots the old root (no subvolume). Removed with «snapshots-setup.sh cleanup».
/Rescue (old root)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux.efi
    cmdline: root=PARTUUID=$ROOT_PARTUUID zswap.enabled=0 rw rootfstype=btrfs
EOF

    echo
    echo "Phase 1 done. Reboot NOW (anything you change in /home before rebooting is lost)."
    echo "After rebooting, check: findmnt -no OPTIONS / | grep subvol=/@"
}

phase2() {
    [[ "$(current_subvol)" == "/@" ]] || die "the root is not in @ (subvol=$(current_subvol)); did you reboot after phase 1?"

    step "snapper («root» config: only the snapshot of the last update)"
    pacman -S --needed --noconfirm snapper
    snapper list-configs | grep -q '^root ' || snapper -c root create-config /
    # A single snapshot: arch-update creates the new one and deletes the previous one at once
    # (NUMBER_MIN_AGE=0: otherwise snapper keeps those younger than 30 min)
    snapper -c root set-config TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=1 NUMBER_LIMIT_IMPORTANT=1 NUMBER_MIN_AGE=0
    systemctl enable --now snapper-cleanup.timer

    step "limine-snapper-sync and arch-update config"
    install -Dm644 "$SYS/etc/default/limine" /etc/default/limine
    install -Dm755 "$SYS/usr/local/bin/arch-update" /usr/local/bin/arch-update

    echo
    echo "Phase 2 done. Now, as the user (without sudo): yay -S limine-snapper-sync"
    echo "and then: sudo $0 phase3"
}

phase3() {
    command -v limine-snapper-sync >/dev/null || die "limine-snapper-sync is missing (yay -S limine-snapper-sync)"
    step "Automatic sync and first snapshot"
    systemctl enable --now limine-snapper-sync.service
    snapper -c root create --cleanup-algorithm number --description "First snapshot"
    snapper -c root cleanup number
    limine-snapper-sync
    echo
    sed -n '/\/\/Snapshots/,/^\/[^/]/p' /boot/limine.conf | head -20
    echo
    echo "Phase 3 done. Reboot and look for the «Snapshots» group inside «Arch Linux» in Limine."
}

# Abort if the path (relative to the top level) is @, @home, something inside them or mounted
protected() {
    case "$1" in
        @|@/*|@home|@home/*) die "«$1» is protected; nothing is deleted" ;;
    esac
    if findmnt -rno SOURCE | grep -qF "[/$1]"; then die "«$1» is mounted; nothing is deleted"; fi
}

cleanup() {
    [[ "$(current_subvol)" == "/@" ]] || die "boot into @ first"
    mkdir -p "$TOP"
    mountpoint -q "$TOP" || mount -o subvolid=5 "UUID=$DEV_UUID" "$TOP"
    mapfile -t old < <(find "$TOP" -mindepth 1 -maxdepth 1 ! -name '@' ! -name '@home' -printf '%f\n' | sort)
    [[ ${#old[@]} -gt 0 ]] || { echo "Nothing to delete."; umount "$TOP"; return; }
    # Subvolumes inside the old root (e.g. var/lib/machines), deepest
    # first. Filtered by path: «btrfs subvolume list -o <dir>» with a normal
    # directory lists the top level's children (@, @home…), which is how @home was deleted once.
    nested=()
    while read -r sv; do
        for n in "${old[@]}"; do
            [[ "$sv" == "$n/"* ]] && nested+=("$sv")
        done
    done < <(btrfs subvolume list "$TOP" | sed 's/^.* path //' | sort -r)
    for n in "${old[@]}" "${nested[@]}"; do protected "$n"; done
    echo "Will be deleted from the old root ($TOP): ${old[*]}"
    [[ ${#nested[@]} -gt 0 ]] && echo "With their subvolumes: ${nested[*]}"
    echo "Kept: @ and @home (and whatever they contain)."
    read -rp "Type DELETE to continue: " r
    [[ "$r" == "DELETE" ]] || die "cancelled"
    for sv in "${nested[@]}"; do
        btrfs subvolume delete "$TOP/$sv"
    done
    for n in "${old[@]}"; do
        rm -rf --one-file-system -- "${TOP:?}/$n"
    done
    umount "$TOP"
    # Remove the «/Rescue…» block (and its comment) even if limine-snapper-sync reordered the file
    # (also the Spanish «/Rescate…» one that older versions of this script added)
    awk '/^# (Temporary: boots the old root|Temporal: arranca la raíz antigua)/ {next}
         /^\/(Rescue|Rescate)/ {skip=1; next}
         skip && /^\/[^\/]/ {skip=0}
         !skip' /boot/limine.conf > /boot/limine.conf.tmp
    mv /boot/limine.conf.tmp /boot/limine.conf
    echo "Old root deleted and «Rescue» entry removed from Limine."
}

case "${1:-}" in
    # fase1…3 and limpiar: the old Spanish names
    phase1|phase2|phase3|cleanup|fase1|fase2|fase3|limpiar)
        [[ $EUID -eq 0 ]] || die "run it with sudo"
        cmd=${1/fase/phase}; [[ $cmd == limpiar ]] && cmd=cleanup
        "$cmd" ;;
    *) sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
