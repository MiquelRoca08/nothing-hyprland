---
name: sistema
description: Arreglar fallos y cambiar la configuración de este Arch Linux (ROG Zephyrus G14, Hyprland 0.56 en Lua, shell propio de Quickshell, walker, greetd, Limine + UKI + Secure Boot, snapper, Plymouth, Howdy), dejándolo todo en ~/dotfiles y documentado en ~/dotfiles/docs. Úsala siempre que pida arreglar algo del sistema o del escritorio («no funciona…», «se cierra…», «sale un error…», «no arranca…») o cambiar una configuración (atajos, barra, Ajustes, tema, monitores, menú, arranque, audio, paquetes…), aunque no nombre los dotfiles.
---

# El sistema: arreglar y configurar

Arch Linux en un ROG Zephyrus G14 (GA403GM) con un escritorio hecho a medida. **Todo** lo que se
toca vive en el repo `~/dotfiles` (https://github.com/MiquelRoca08/nothing-hyprland; lo privado, en `privado/`, fuera de git) y **todo** cambio se
documenta en `~/dotfiles/docs/`. Idiomas: al usuario se le responde en español; la documentación (`docs/`, README) y los mensajes de
commit y los comentarios del código van en **inglés** (el repo es público); los textos de la interfaz del shell
se escriben en inglés dentro de `I18n.tr("…")` y su español va en `quickshell/i18n/es.js`.

## Antes de tocar nada: leer

1. **La documentación del área** (es la memoria del sistema: qué se hizo, por qué y qué falló antes):

   | Área | Documento |
   |---|---|
   | Hardware, audio, login (greetd), arranque (Limine, UKI, Plymouth), snapshots, Secure Boot, Howdy, varios | `docs/SYSTEM.md` |
   | Hyprland: módulos de `conf/`, atajos, monitores, X11 | `docs/HYPRLAND.md` |
   | Shell de Quickshell: barra, Ajustes, pantalla de bloqueo, temas, OSD, notificaciones | `docs/QUICKSHELL.md` y **`home/.config/quickshell/CLAUDE.md`** (reglas de diseño, trampas de QML y cómo probar) |
   | Lanzador y menú del sistema (walker, elephant, `~/.local/bin/menu`) | `docs/WALKER.md` |

   Mira también la sección «Pendiente» del documento: a veces el fallo ya está apuntado.
2. **`references/diagnostico.md`**: dónde están los registros y qué comandos usar en cada parte.
3. **El archivo real** antes de cambiarlo, y lo que lo genera si es un archivo generado (ver abajo).

## Dónde se cambia cada cosa

- **`home/`** se enlaza a `$HOME` (lista en `enlaces.txt`; `./install.sh` crea los enlaces). Edita
  siempre dentro de `~/dotfiles/home/…`: `~/.config/hypr` y compañía son enlaces a esa carpeta.
  Si añades una ruta nueva a `$HOME`, añádela a `enlaces.txt`.
- **`system/`** son **copias** de archivos de `/` (`/etc`, `/boot`, `/usr/local`…). Cambia la copia
  del repo y cópiala con `sudo install -Dm644 system/<ruta> /<ruta>` (o `./install.sh sistema`,
  que además ejecuta `mkinitcpio -P` si toca el initramfs). Nunca cambies solo el de `/`: la próxima instalación lo
  pisaría. Excepciones que `install.sh` no pisa: `/etc/fstab` y `/boot/limine.conf` si son de otro
  disco, y `/boot/limine.conf` si ya tiene snapshots (lo reescribe limine-snapper-sync; para
  cambiarlo, edita `/boot/limine.conf` y también la plantilla `system/boot/limine.conf`).
- **Paquetes nuevos:** a `paquetes.txt` (repos) o `paquetes-aur.txt` (AUR), con un comentario de
  para qué es. Un servicio que haga falta, a `instalar/30-servicios.sh`. `install.sh` va por módulos
  (`instalar/NN-nombre.sh`, ver README) y pregunta antes de cada acción: es para que lo ejecute el usuario.
- **Scripts propios:** `home/.local/bin/` (del usuario) o `system/usr/local/bin/` (`arch-update`).

### Archivos generados: no se editan a mano

| Archivo | Lo genera | Qué cambiar en su lugar |
|---|---|---|
| `hypr/conf/shell-settings.lua` | Quickshell (`Config.qml`, desde `settings.json`) | La opción en `Config.qml` / la página de Ajustes |
| `hypr/conf/tema.lua`, `gtk-{3,4}.0/tema.css`, `walker/themes/nothing/tema.css`, `~/.local/share/quickshell/tema/*` | `quickshell/scripts/tema.sh aplicar` | El tema (`quickshell/temas/*.json`) o `tema.sh` |
| `hypr/conf/monitors.lua` | Ajustes → Pantallas (solo los `hl.monitor` de los monitores conectados) | Se puede editar a mano, pero lo que no sea `hl.monitor` se pierde al aplicar desde Ajustes |
| `/boot/limine.conf` | limine-snapper-sync (añade las snapshots) | Ver arriba |
| Imágenes de arranque (`splash.bmp`, `logo.png` de Plymouth, `limine-nothing.png`) | `scripts/logo-arranque.py` | El script |

## Trampas conocidas (no las repitas)

- **Hyprland 0.56 usa Lua**, no hyprlang: `hl.config({...})`, `hl.bind(...)`, `hl.window_rule({...})`,
  `require("conf.x")` / `pcall(require, "conf.x")`. Los dispatch también: `hyprctl dispatch
  'hl.dsp.exec_cmd("qs")'` (la sintaxis clásica `hyprctl dispatch exec qs` da error). Hyprland
  recarga solo al guardar; tras cambiar, `hyprctl configerrors` debe salir vacío.
- **Quickshell 0.3.1** (sin APIs de `-git`). Antes de cambiar QML, lee
  `home/.config/quickshell/CLAUDE.md`: propiedades que rompen la carga (`onX` en propiedades,
  `states`, `top`, `children`, `implicitWidth` de `Image`), `Flickable` que se queda los clics,
  `MouseArea` con hover dentro de un `HoverHandler`… y los componentes que hay que reutilizar
  (`SettingsPage`, `SettingsGroup`, `SettingsRow`, `Button`, `ChoiceChips`, `Toggle`,
  `SliderField`, `WifiField`, `IconButton`, `Terminal`…). Los colores, solo de `Theme.qml`.
- **Initramfs / UKI:** tras cambiar `mkinitcpio.conf`, los hooks, `/etc/mkinitcpio.d/linux.preset`,
  el firmware, `modprobe.d` o Plymouth → `sudo mkinitcpio -P`. sbctl firma la UKI sola. La UKI va
  **sin cmdline** (`--no-cmdline`): las opciones del kernel están en `/boot/limine.conf`.
- **Plymouth está desactivado a propósito** (`plymouth.enable=0` y sin hook): dejaba sin imagen el
  monitor de la NVIDIA (`Cannot commit when a page-flip is awaiting` en el registro de Hyprland).
  No lo reactives sin leer «Quiet boot» en `docs/SYSTEM.md`.
- **Secure Boot:** cualquier `.EFI` nuevo o reescrito tiene que estar firmado (`sudo sbctl verify`).
  Si no arranca, desactivar Secure Boot en la BIOS arranca igual.
- **Monitores:** `eDP-1` (portátil, 2880×1800, escala 1,8–2, AMD) y `DP-9` (AOC 27", 2560×1440 a
  180 Hz, escala 1, NVIDIA). Lo que dependa del tamaño en píxeles, compruébalo con las dos escalas.
- **Terminales desde el shell:** `dash` no tiene `read -p`; usa `Terminal.run`/`Terminal.open`
  (QML) o `bash -c`. Las ventanas de terminal del menú son de clase `menu-terminal`.
- **Datos separados por `|` o tabuladores** en scripts: los campos vacíos se pierden con `IFS=$'\t'`;
  usa `\037`. En awk, `printf ... > 0` redirige a un archivo llamado «0»: pon paréntesis.
- **`/etc/pam.d/sudo`** es del paquete `sudo` (lleva la línea de Howdy): si llega un `.pacnew`, hay
  que volver a añadirla.

## Cómo trabajar

1. **Reproduce o entiende el fallo** con los registros (`references/diagnostico.md`), no a ciegas.
   Si el usuario pega un error o una captura, empieza por ahí. Si falta un dato que solo está en su
   equipo, pídele el comando exacto que tiene que ejecutar y qué salida esperas.
2. **Busca la causa**, no solo el síntoma: si el mismo fallo puede repetirse en otro sitio (otro
   componente con el mismo patrón, otra página de Ajustes), arréglalo también.
3. **Haz el cambio mínimo** en `~/dotfiles`, con el estilo del archivo que tocas (comentarios en
   inglés, igual de densos que los de alrededor).
4. **Valida antes de dar nada por hecho**, con lo que haya a mano:
   - Bash: `bash -n script`; y si es posible, ejecútalo con datos de prueba.
   - Hyprland: `hyprctl configerrors`; `hyprctl reload` si hace falta.
   - QML: `qmllint -I . Archivo.qml` y, para ver una página, la prueba sin pantalla que explica
     `quickshell/CLAUDE.md`; luego reiniciar el shell:
     `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'` y mirar `qs log`.
   - Sistema: `systemctl status <unidad>`, `journalctl -b -u <unidad>`, `sudo sbctl verify`.
   Si no has podido probarlo de verdad (p. ej. el arranque), dilo claramente y explica cómo
   comprobarlo.
5. **Documenta** en `~/dotfiles/docs/` (ver abajo). Un cambio sin documentar no está terminado.
6. **Commit y push** desde `~/dotfiles`, en inglés: primera línea «Area: what changes», y en el
   cuerpo el porqué (causa del fallo). El usuario trabaja directamente en `main` y hace push; si hay
   cambios suyos sin subir, no los pises (`git status` y `git pull` antes).
7. **Responde** con: qué fallaba y por qué, qué has cambiado, cómo lo has comprobado (o qué no has
   podido comprobar) y los pasos que le tocan a él, con los comandos listos para copiar (casi
   siempre `cd ~/dotfiles && git pull` y reiniciar lo afectado; con archivos de `system/`,
   `./install.sh` o solo `./install.sh sistema arranque`, que ya ejecuta `mkinitcpio -P` si toca el initramfs).

## Documentar en ~/dotfiles/docs

- **Dónde:** en el documento del área (tabla de arriba), en la sección que corresponda o en una
  nueva `## …` si es un tema nuevo. Si abres una sección de sistema nueva, añade también su fila a
  «Qué vive dónde» de `SYSTEM.md`. Un área nueva que no encaje en ninguno → documento nuevo en
  `docs/` y enlázalo desde `README.md` (tabla de documentos) y desde los documentos relacionados.
- **Qué contar** (en inglés, en viñetas, frases cortas, con rutas y comandos en `código`):
  - **Arreglo de un fallo:** fecha (p. ej. «28 sep»), síntoma tal como se veía, causa, arreglo
    (archivo y cambio) y cómo comprobarlo. Si queda algo sin confirmar, a «Pendiente».
  - **Cambio de configuración:** qué hace ahora, dónde se cambia (archivo o página de Ajustes) y,
    si hay una decisión no obvia, por qué se eligió así y qué se descartó.
- **Mantén el documento como descripción del estado actual:** reescribe lo que ya no es verdad en
  vez de apilar notas contradictorias; la historia solo cuando explique una decisión o un fallo que
  puede volver.
- **«Pendiente / por comprobar»:** añade lo que no se pudo probar; quita lo que quede resuelto.
- Si cambias algo que el `README.md` describe (estructura del repo, `system/`, scripts), actualízalo.
- `~/Documents/SYSTEM.md` es un enlace a `docs/SYSTEM.md`: no hay que copiar nada.
