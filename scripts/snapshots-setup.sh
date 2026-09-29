#!/usr/bin/env bash
#
# Pasa la raíz btrfs a subvolúmenes (@ y @home) y monta snapper + limine-snapper-sync
# para que las snapshots que crea arch-update salgan en Limine. Se hace por fases:
#
#   sudo ./snapshots-setup.sh fase1    # crea @ y @home, initramfs con overlay, Limine → reiniciar
#   sudo ./snapshots-setup.sh fase2    # (ya en @) snapper, config de Limine y arch-update
#        yay -S limine-snapper-sync    # como usuario, sin sudo
#   sudo ./snapshots-setup.sh fase3    # activa la sincronización y crea la primera snapshot
#   sudo ./snapshots-setup.sh limpiar  # (cuando todo funcione) borra la raíz antigua
#
# Hasta «limpiar», la raíz antigua sigue intacta y Limine tiene la entrada «Rescate».
set -euo pipefail

SYS="$(cd "$(dirname "$0")/../system" && pwd)"
# This machine's btrfs root partition (filesystem UUID and partition PARTUUID)
RAIZ_DEV="$(findmnt -no SOURCE / | sed 's/\[.*//')"
DEV_UUID="$(lsblk -no UUID "$RAIZ_DEV")"
ROOT_PARTUUID="$(lsblk -no PARTUUID "$RAIZ_DEV")"
TOP="/mnt/btrfs-raiz"

die() { echo "ERROR: $*" >&2; exit 1; }
paso() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

subvol_actual() { findmnt -no OPTIONS / | tr ',' '\n' | sed -n 's/^subvol=//p'; }

fase1() {
    [[ "$(subvol_actual)" == "/" ]] || die "la raíz ya no es el volumen entero (subvol=$(subvol_actual)); ¿ya hiciste la fase 1?"
    # An earlier interrupted attempt leaves /@ and /@home: they are only copies made
    # by this phase (the current root is the good one), so they are deleted and redone
    for sv in /@ /@home; do
        if [[ -e "$sv" ]]; then
            echo "Borrando $sv de un intento anterior…"
            btrfs subvolume delete "$sv"
        fi
    done

    paso "Initramfs: hook btrfs-overlayfs y UKI sin cmdline incrustada (la pone limine.conf)"
    install -Dm644 "$SYS/etc/initcpio/install/btrfs-overlayfs" /etc/initcpio/install/btrfs-overlayfs
    install -Dm644 "$SYS/etc/initcpio/hooks/btrfs-overlayfs" /etc/initcpio/hooks/btrfs-overlayfs
    install -Dm644 "$SYS/etc/mkinitcpio.conf" /etc/mkinitcpio.conf
    install -Dm644 "$SYS/etc/mkinitcpio.d/linux.preset" /etc/mkinitcpio.d/linux.preset
    rm -f /etc/kernel/cmdline
    mkinitcpio -P

    paso "Subvolúmenes @ y @home (instantáneas del volumen actual; no copian datos)"
    sync
    btrfs subvolume snapshot / /@
    btrfs subvolume snapshot / /@home

    paso "@home: solo el contenido de /home"
    shopt -s dotglob nullglob
    # Without --one-file-system: nested subvolumes (/var/lib/machines…) show up
    # in the copy as empty directories on another device and it would refuse to delete them
    for e in /@home/*; do
        [[ "$e" == /@home/home ]] && continue
        rm -rf -- "$e"
    done
    mv /@home/home/* /@home/
    rmdir /@home/home

    paso "@: /home vacío (su contenido está en @home) y fstab nuevo"
    for e in /@/home/*; do rm -rf -- "$e"; done
    install -Dm644 "$SYS/etc/fstab" /@/etc/fstab
    shopt -u dotglob nullglob

    paso "Limine: entrada en @, snapshots y «Rescate» (raíz antigua)"
    # At the root of the partition (/boot/limine.conf), which is where
    # limine-snapper-sync looks for it; Limine finds it there if there is none in /EFI/BOOT/
    [[ -f /boot/EFI/BOOT/limine.conf ]] && mv /boot/EFI/BOOT/limine.conf /boot/EFI/BOOT/limine.conf.antes-de-snapshots
    install -Dm644 "$SYS/boot/limine.conf" /boot/limine.conf
    install -Dm644 "$SYS/boot/EFI/BOOT/limine-nothing.png" /boot/EFI/BOOT/limine-nothing.png
    cat >> /boot/limine.conf <<EOF

# Temporal: arranca la raíz antigua (sin subvolumen). Se quita con «snapshots-setup.sh limpiar».
/Rescate (raíz antigua)
    protocol: efi
    path: boot():/EFI/Linux/arch-linux.efi
    cmdline: root=PARTUUID=$ROOT_PARTUUID zswap.enabled=0 rw rootfstype=btrfs
EOF

    echo
    echo "Fase 1 hecha. Reinicia YA (lo que cambies en /home antes de reiniciar se pierde)."
    echo "Tras reiniciar comprueba: findmnt -no OPTIONS / | grep subvol=/@"
}

fase2() {
    [[ "$(subvol_actual)" == "/@" ]] || die "la raíz no está en @ (subvol=$(subvol_actual)); ¿reiniciaste tras la fase 1?"

    paso "snapper (config «root»: solo la snapshot de la última actualización)"
    pacman -S --needed --noconfirm snapper
    snapper list-configs | grep -q '^root ' || snapper -c root create-config /
    # A single snapshot: arch-update creates the new one and deletes the previous one at once
    # (NUMBER_MIN_AGE=0: otherwise snapper keeps those younger than 30 min)
    snapper -c root set-config TIMELINE_CREATE=no NUMBER_CLEANUP=yes NUMBER_LIMIT=1 NUMBER_LIMIT_IMPORTANT=1 NUMBER_MIN_AGE=0
    systemctl enable --now snapper-cleanup.timer

    paso "Config de limine-snapper-sync y arch-update"
    install -Dm644 "$SYS/etc/default/limine" /etc/default/limine
    install -Dm755 "$SYS/usr/local/bin/arch-update" /usr/local/bin/arch-update

    echo
    echo "Fase 2 hecha. Ahora, como usuario (sin sudo): yay -S limine-snapper-sync"
    echo "y después: sudo $0 fase3"
}

fase3() {
    command -v limine-snapper-sync >/dev/null || die "falta limine-snapper-sync (yay -S limine-snapper-sync)"
    paso "Sincronización automática y primera snapshot"
    systemctl enable --now limine-snapper-sync.service
    snapper -c root create --cleanup-algorithm number --description "Primera snapshot"
    snapper -c root cleanup number
    limine-snapper-sync
    echo
    sed -n '/\/\/Snapshots/,/^\/[^/]/p' /boot/limine.conf | head -20
    echo
    echo "Fase 3 hecha. Reinicia y mira el grupo «Snapshots» dentro de «Arch Linux» en Limine."
}

# Abort if the path (relative to the top level) is @, @home, something inside them or mounted
protegido() {
    case "$1" in
        @|@/*|@home|@home/*) die "«$1» está protegido; no se borra nada" ;;
    esac
    if findmnt -rno SOURCE | grep -qF "[/$1]"; then die "«$1» está montado; no se borra nada"; fi
}

limpiar() {
    [[ "$(subvol_actual)" == "/@" ]] || die "arranca primero en @"
    mkdir -p "$TOP"
    mountpoint -q "$TOP" || mount -o subvolid=5 "UUID=$DEV_UUID" "$TOP"
    mapfile -t viejos < <(find "$TOP" -mindepth 1 -maxdepth 1 ! -name '@' ! -name '@home' -printf '%f\n' | sort)
    [[ ${#viejos[@]} -gt 0 ]] || { echo "Nada que borrar."; umount "$TOP"; return; }
    # Subvolumes inside the old root (e.g. var/lib/machines), deepest
    # first. Filtered by path: «btrfs subvolume list -o <dir>» with a normal
    # directory lists the top level's children (@, @home…), which is how @home was deleted once.
    anidados=()
    while read -r sv; do
        for n in "${viejos[@]}"; do
            [[ "$sv" == "$n/"* ]] && anidados+=("$sv")
        done
    done < <(btrfs subvolume list "$TOP" | sed 's/^.* path //' | sort -r)
    for n in "${viejos[@]}" "${anidados[@]}"; do protegido "$n"; done
    echo "Se borrará de la raíz antigua ($TOP): ${viejos[*]}"
    [[ ${#anidados[@]} -gt 0 ]] && echo "Con sus subvolúmenes: ${anidados[*]}"
    echo "Se conservan: @ y @home (y lo que tengan dentro)."
    read -rp "Escribe BORRAR para continuar: " r
    [[ "$r" == "BORRAR" ]] || die "cancelado"
    for sv in "${anidados[@]}"; do
        btrfs subvolume delete "$TOP/$sv"
    done
    for n in "${viejos[@]}"; do
        rm -rf --one-file-system -- "${TOP:?}/$n"
    done
    umount "$TOP"
    # Remove the «/Rescate…» block (and its comment) even if limine-snapper-sync reordered the file
    awk '/^# Temporal: arranca la raíz antigua/ {next}
         /^\/Rescate/ {skip=1; next}
         skip && /^\/[^\/]/ {skip=0}
         !skip' /boot/limine.conf > /boot/limine.conf.tmp
    mv /boot/limine.conf.tmp /boot/limine.conf
    echo "Raíz antigua borrada y entrada «Rescate» quitada de Limine."
}

case "${1:-}" in
    fase1|fase2|fase3|limpiar) [[ $EUID -eq 0 ]] || die "ejecútalo con sudo"; "$1" ;;
    *) sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
