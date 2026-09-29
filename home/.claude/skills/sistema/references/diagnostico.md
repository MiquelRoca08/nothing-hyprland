# Diagnóstico por área

Registros y comandos para ver qué pasa antes de cambiar nada. Los que llevan `sudo` los tiene que
ejecutar el usuario si no hay acceso a su equipo: pídeselos con el comando exacto.

## General

- Errores de este arranque: `journalctl -b -p 3 --no-pager` (`-b -1`: el arranque anterior)
- Unidades que han fallado: `systemctl --failed` y `systemctl --user --failed`
- Qué ha cambiado en los paquetes: `grep -E 'upgraded|installed|removed' /var/log/pacman.log | tail -40`
- `.pacnew` pendientes: `pacdiff -o` (o `find /etc -name '*.pacnew'`)
- Diferencias entre el repo y `/`: `cd ~/dotfiles/system && find . -type f | while read f; do cmp -s "$f" "/${f#./}" || echo "distinto: /${f#./}"; done`
- Enlaces rotos de los dotfiles: `cd ~/dotfiles && grep -vE '^#|^$' enlaces.txt | while read p; do [ "$(readlink -f ~/$p)" = "$PWD/home/$p" ] || echo "mal: ~/$p"; done`

## Hyprland (`home/.config/hypr/`, docs/HYPRLAND.md)

- Errores de la config: `hyprctl configerrors` (también en Ajustes → Personalización → Hyprland).
- Registro: `$XDG_RUNTIME_DIR/hypr/*/hyprland.log` (el de la sesión actual:
  `ls -t $XDG_RUNTIME_DIR/hypr/ | head -1`).
- Estado: `hyprctl monitors`, `hyprctl devices`, `hyprctl clients`, `hyprctl binds`,
  `hyprctl getoption <sección:opción>`, `hyprctl version`.
- Módulos: `hyprland.lua` solo tiene `require("conf.…")`; cada módulo es un ámbito aparte (un error
  en uno no tumba los demás).

## Shell de Quickshell (`home/.config/quickshell/`, docs/QUICKSHELL.md y su CLAUDE.md)

- Registro del shell en marcha: `qs log` (o `qs log -f` para seguirlo). Al reiniciarlo desde una
  terminal (`pkill -x qs; qs`), los errores de QML salen en la propia terminal.
- Reiniciar: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- IPC (lo que expone cada `IpcHandler`): `qs ipc show`; p. ej. `qs ipc call settings open wifi`,
  `qs ipc call lock prueba`, `qs ipc call osd brightness`.
- Un componente que no carga deja «Type X unavailable» en quien lo usa: el fallo está en X
  (o en algo que X usa), no en el que avisa.
- Ajustes guardados: `~/.config/quickshell/settings.json` (lo escribe `Config.qml`).
- Tema activo: `~/.local/share/quickshell/tema/actual.json`; volver a generarlo:
  `~/.config/quickshell/scripts/tema.sh aplicar ~/.local/share/quickshell/tema/actual.json`.

## Lanzador y menú (walker, elephant; docs/WALKER.md)

- `systemctl --user status walker elephant`, `journalctl --user -u walker -u elephant -b`.
- Reiniciar: `walker-restart` (o `systemctl --user restart elephant walker`).
- El menú del sistema: `~/.local/bin/menu` (`menu --entradas-todas` da la tabla completa, sin
  filtrar por lo que se oculta en Ajustes → QuickShell → Menú).

## Login, bloqueo e inactividad

- greetd (autologin): `journalctl -b -u greetd`, `/etc/greetd/config.toml`.
- Bloqueo: `~/.local/bin/bloquear` (shell y, si no responde en 5 s, hyprlock de respaldo); PAM en
  `/etc/pam.d/quickshell-lock` y `quickshell-lock-cara`; fallos de PAM: `journalctl -b | grep -iE 'pam|faillock'`.
  Intentos fallidos: `faillock --user $USER` (desbloquear: `faillock --user $USER --reset`).
- Inactividad: `~/.config/hypr/hypridle.conf` (lo genera el shell), `pgrep -a hypridle`.
- Howdy: `sudo howdy test`, `sudo howdy list`, `journalctl -b | grep -i howdy`.

## Arranque (Limine, UKI, Plymouth, Secure Boot; docs/SYSTEM.md)

- Opciones con las que arrancó el kernel: `cat /proc/cmdline`.
- Limine: `/boot/limine.conf` (el real, con snapshots) frente a `system/boot/limine.conf` (plantilla).
- UKI: `/boot/EFI/Linux/arch-linux.efi`; se rehace con `sudo mkinitcpio -P` (hooks en
  `/etc/mkinitcpio.conf`, opciones en `/etc/mkinitcpio.d/linux.preset`).
- Plymouth: desactivado (`plymouth.enable=0`, ver docs/SYSTEM.md). Tema en `/etc/plymouth/plymouthd.conf`;
  probarlo sin reiniciar: `sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth quit`.
- Monitor de 27" sin imagen: `grep -iE 'DP-9|page-flip' "$XDG_RUNTIME_DIR/hypr/$(ls -t $XDG_RUNTIME_DIR/hypr/ | head -1)/hyprland.log" | tail`
  y `cat /proc/cmdline` (¿sigue `plymouth.enable=0`?).
  Ver los mensajes de un arranque: `Esc` durante el logo, o quitar `quiet splash` en Limine (`E`).
- Tiempos: `systemd-analyze`, `systemd-analyze blame | head`, `systemd-analyze critical-chain`.
- Secure Boot: `sudo sbctl verify`, `sbctl status`; firmar lo que ya conoce: `sudo sbctl sign-all`.

## Snapshots y actualizaciones

- `sudo snapper -c root list`, `/etc/snapper/configs/root`, `/etc/default/limine`.
- `arch-update` (`system/usr/local/bin/arch-update`); desde el shell, Ajustes → Actualizaciones.
- Espacio en `/boot` (1 GiB, la UKI ~170 MiB): `df -h /boot`.

## Audio, pantallas y periféricos

- Audio: `wpctl status`, `wpctl inspect @DEFAULT_AUDIO_SINK@`, `pactl list short sinks`,
  `journalctl --user -u wireplumber -u pipewire -b`. Arreglo del G14: `/etc/modprobe.d/g14-audio.conf`
  y `/usr/lib/firmware/g14-audio.fw` (necesitan `mkinitcpio -P` y reiniciar).
- Brillo: `~/.config/quickshell/scripts/brillo.sh get [monitor]`; externo por DDC/CI:
  `ddcutil detect` (grupo `i2c`, módulo `i2c-dev`).
- Monitores: `hyprctl monitors all`, `~/.config/hypr/conf/monitors.lua`.
- Red: `nmcli device status`, `nmcli connection show`, `resolvectl status`.
- Bluetooth: `bluetoothctl show`, `bluetoothctl devices`, `systemctl status bluetooth`.
- Impresoras: `lpstat -t`, `journalctl -b -u cups`, `~/.config/quickshell/scripts/impresoras.sh estado`.
- Entrada (teclado, ratón, touchpad): `hyprctl devices`; opciones en `conf/shell-settings.lua`
  (generado) y `conf/input.lua` (gestos, dispositivos concretos, reglas por app).
