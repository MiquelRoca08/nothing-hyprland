# nothing-hyprland

Un escritorio Arch Linux monocromo inspirado en Nothing OS: **Hyprland 0.56 (config en Lua)**, un
shell propio de **Quickshell** (barra, notificaciones, OSD, pantalla de bloqueo y una app de
Ajustes completa) y un lanzador y menú del sistema con **walker**, con arranque temático (Limine +
UKI) y un instalador interactivo.

> [!NOTE]
> Hecho en un **ASUS ROG Zephyrus G14 (GA403)**: gráfica integrada AMD + NVIDIA, pantalla de
> 2880×1800 y un monitor externo de 1440p. El escritorio (`home/`) funciona en cualquier Arch con
> Hyprland; algunos archivos de `system/` y algunos valores por defecto son de ese portátil.
> [`docs/HARDWARE.md`](docs/HARDWARE.md) (en inglés) los lista y explica qué cambiar en otro
> hardware. Lee lo que pregunta el instalador antes de decir que sí.

*[Read in English](README.md)* · La documentación y los comentarios del código están en inglés; la
interfaz del shell, en inglés o en español, según el locale del sistema (Ajustes → Sistema → Idioma lo cambia).

## Capturas

<!-- screenshots: docs/img/desktop.png, docs/img/settings.png, docs/img/menu.png, docs/img/lock.png -->

Aquí irán capturas del escritorio, la app de Ajustes, el menú del sistema y la pantalla de bloqueo.

## Lo más destacado

- **Shell de Quickshell** (`home/.config/quickshell/`): barra con módulos que se arrastran, centro
  de notificaciones, OSD, menú de apagado, selector de compartir pantalla con vista previa,
  pantalla de bloqueo con PAM y desbloqueo facial (Howdy) y una **app de Ajustes**: pantallas
  (disposición arrastrando), sonido, Wi-Fi (con DNS propio), Bluetooth, impresoras (CUPS y avahi),
  teclado y ratón, editor de atajos, limpieza de almacenamiento, aplicaciones (instaladas e
  instalar de pacman, AUR, Flatpak, WebApps y TUIs), fuentes, fondos (con buscador de Wallhaven),
  **temas de todo el escritorio** (con todo el catálogo base16), actualizaciones con snapshots y más.
- **Temas que llegan a todo:** un tema cambia el shell, Alacritty, walker, las apps GTK 3/4 y los
  bordes de Hyprland.
- Lanzador **walker** y **menú del sistema** estilo Omarchy (`SUPER+SPACE`), configurable desde Ajustes.
- **Arranque silencioso:** menú de Limine limpio y splash de la UKI con el logo «NOTHING OS LINUX» en
  puntos, sin texto de consola; Secure Boot con sbctl; snapshots de btrfs en el menú de arranque
  (snapper + limine-snapper-sync).
- **Instalador interactivo por módulos:** cada acción enseña el comando exacto y pregunta antes.

## Requisitos

- **Arch Linux** (x86_64) ya instalado y arrancando, con un usuario que pueda usar `sudo`, conexión
  a internet y `git`. El instalador se ejecuta como ese usuario, desde una terminal (no como root).
- **UEFI**, con la partición EFI montada en **`/boot`** (1 GiB aprox.: la imagen unificada del
  kernel ocupa ~170 MiB y cada snapshot puede guardar su copia).
- El kernel **`linux`** (el preset de la UKI es `/etc/mkinitcpio.d/linux.preset`) y los **drivers
  de tu gráfica** (no están en `packages.txt`; p. ej. `nvidia-open` + `nvidia-utils` para NVIDIA).
- **Limine** como gestor de arranque. El instalador escribe su configuración (`/boot/limine.conf`),
  pero no instala Limine en la ESP ni crea la entrada de arranque del firmware.
- **btrfs recomendado**, con la raíz en un subvolumen `@` y home en `@home`: la plantilla de Limine
  arranca con `rootflags=subvol=/@` y las snapshots lo necesitan. Una raíz btrfs sin subvolúmenes
  se puede migrar con `scripts/snapshots-setup.sh` ([docs/SYSTEM.md](docs/SYSTEM.md#setting-up-snapshots-on-an-existing-btrfs-root)).
  Con otro sistema de archivos, edita `system/boot/limine.conf` antes de ejecutar el módulo
  `system` y sáltate lo de las snapshots.
- **Opcional:** Secure Boot (las claves las creas y registras tú con `sbctl`), una cámara IR para el
  desbloqueo facial (Howdy) y un monitor externo con DDC/CI para controlar su brillo.

## Instalar

```sh
git clone https://github.com/MiquelRoca08/nothing-hyprland.git ~/dotfiles
cd ~/dotfiles
./install.sh          # todos los módulos, preguntando antes de cada acción
```

`./install.sh` recorre los módulos de [`installer/`](installer/) en orden. Cada uno explica qué hace
y, **antes de cada acción, enseña el comando exacto y pregunta** (como el instalador de
illogical-impulse):

- `y` (o Enter): sí.
- `n`: no; salta el resto de ese módulo y sigue con el siguiente.
- `yall`: sí a todo, sin volver a preguntar (salvo si algo falla).
- `q`: salir.

Si un comando falla, pregunta siempre: reintentar, seguir, saltar el módulo o salir. Al final sale
un resumen. Cada módulo solo hace lo que falta, así que se puede repetir tras un `git pull`.

| Módulo | Qué hace |
|---|---|
| `features` | Lista las [funciones opcionales](features.txt) (Bluetooth, impresoras, Howdy, herramientas de ASUS, DDC/CI, Flatpak, WebApps, Spotify, OCR, grabación, firmware) en un selector fzf como el Instalar / Quitar del menú (Tab marca varias, detalles abajo) y te deja quitar las que no quieras: no se instalan (se desinstalan si ya lo están, salvo paquetes que necesiten otros programas), sus servicios no se activan y sus archivos de sistema no se copian. Se guarda en `excluded-features.txt` (fuera de git); los demás módulos lo respetan |
| `packages` | `pacman -Syu --needed` con [`packages.txt`](packages.txt) (de paso actualiza el sistema); antes lista cada paquete con lo que ocupa y el total |
| `aur` | `yay -S --needed` con [`packages-aur.txt`](packages-aur.txt); si no hay yay, lo compila antes |
| `services` | Activa NetworkManager, bluetooth, power-profiles-daemon, cups y avahi; te añade al grupo `i2c` |
| `links` | Enlaza en `$HOME` las rutas de [`links.txt`](links.txt) desde `home/` (o `private/home/`); lo que ya exista se guarda como `.bak-<fecha>`; quita los enlaces que dejaron archivos renombrados. Antes de sustituir un `~/.config/hypr` que ya exista, conserva sus monitores y apps de inicio (ver [más abajo](#tu-configuración-anterior-de-hyprland)); activa los hooks de git del repo (`.githooks/`: recargan Hyprland tras un `git pull` que cambie su configuración) |
| `appearance` | Prompt de bash, colores del tema, cursor de respaldo, gsettings, servicios de walker/elephant y `xdph.conf` |
| `system` | Copia a `/` los archivos de `system/` que han cambiado, rellenando las plantillas con los datos de este equipo |
| `boot` | Opciones del kernel en `/boot/limine.conf`, Plymouth enmascarado y `mkinitcpio -P` si hace falta |
| `login` | Autologin con greetd en vez de SDDM |

Solo algunos, por nombre: `./install.sh links system boot`. `./install.sh -h` lista los módulos con
su descripción. Habla inglés o español según `$LANG`; `--lang en|es` lo fuerza
(`./install.sh --lang es`).

Un módulo nuevo es un archivo `installer/NN-nombre.sh` con `TITLE`, `DESCRIPTION` y una función
`module()` que hace cada acción con `step "qué hace" comando…` (`installer/lib.sh`); sus textos
pasan por `t "texto en inglés"`, con el español en `home/.config/quickshell/i18n/es.js`.

### Tu configuración anterior de Hyprland

El módulo `links` sustituye `~/.config/hypr` por la configuración modular en Lua del repo (la carpeta
antigua se guarda como `~/.config/hypr.bak-<fecha>`). No fusiona el resto de tu configuración antigua,
pero antes de sustituirla conserva dos cosas, en archivos que son tuyos y no van a git
([`installer/hypr-import.py`](installer/hypr-import.py)):

- **Monitores → `conf/monitors.lua`.** Las reglas `monitor =` / `monitorv2` de un `hyprland.conf`
  (siguiendo los `source =`) o las `hl.monitor` de una configuración en Lua. Si no hay ninguna, los
  monitores tal y como los tiene la sesión de Hyprland en marcha. Siempre se añade una regla de
  respaldo para cualquier otro monitor (modo preferido, posición y escala automáticas). Después,
  Ajustes → Pantallas reescribe este archivo.
- **Apps de inicio → `conf/autostart-local.lua`.** Los comandos `exec-once` / `exec` (o las llamadas
  a `hl.exec_cmd`), como una lista que `conf/autostart.lua` ejecuta al arrancar. Lo que este escritorio
  ya hace (barra, notificaciones, fondo, inactividad, bloqueo, lanzador, portapapeles…) se escribe
  comentado, con el motivo, para que no haya dos barras ni dos demonios de notificaciones. Las reglas
  como `[workspace 2 silent]` se descartan (se indica en un comentario).

Sin configuración anterior, `conf/monitors.lua` se crea igualmente (de la sesión en marcha o solo con
la regla de respaldo). Los dos archivos solo se escriben si aún no existen: edítalos a tu gusto.

### Desinstalar

Tu carpeta personal solo recibe **enlaces** a este repo, así que si borras la carpeta del repo se
quedan rotos: Hyprland, el shell, el menú y los scripts pierden su configuración, y tus ajustes se van
con la carpeta (`settings.json`, `monitors.lua` y `autostart-local.lua` están dentro). Los archivos de
sistema copiados a `/` y los paquetes se quedan. Aun así el autologin es seguro: `autologin-session`
solo arranca Hyprland si está la configuración que lo bloquea; si no, greetd pide la contraseña.

Para deshacerlo de forma limpia, ejecuta **`./install.sh uninstall`** (nunca entra en una ejecución
normal). Para los servicios de walker/elephant, quita los enlaces y restaura las copias `.bak` de lo
que tenías antes, desactiva el autologin de greetd, quita la línea del prompt de `~/.bashrc`, los
archivos de tema generados y los ajustes de GTK y, si quieres, vuelve a SDDM y borra los datos del
shell. Después cierra sesión y borra la carpeta si quieres.

## Primeros pasos después de instalar

1. **Reinicia.** greetd inicia la sesión y aparece enseguida la pantalla de bloqueo: desbloquea con
   tu contraseña. Si se añadió el grupo `i2c`, así se aplica.
2. **Atajos:** `SUPER+K` los lista todos, `SUPER+SPACE` abre el menú del sistema y `SUPER+I`,
   Ajustes. Los principales están en [docs/HYPRLAND.md](docs/HYPRLAND.md#keybinds).
3. **Pantallas:** el módulo `links` ha creado `conf/monitors.lua` para tu equipo (a partir de tu
   configuración anterior de Hyprland, de la sesión en marcha o, si no hay ninguna, cada monitor en su
   modo preferido). Ajústalo en Ajustes → Sistema → Pantallas: coloca tus monitores, elige resolución y
   escala y pulsa Aplicar (tienes 15 s para Mantener).
4. **Aspecto:** Ajustes → Personalización → Fondo de pantalla y Temas; Ajustes → Sistema → Idioma.
5. **Revisa el hardware:** lee [docs/HARDWARE.md](docs/HARDWARE.md) y quita lo que no te sirva
   (p. ej. `asusctl`/`rog-control-center` o el parche de audio del G14). Tus apps de inicio van en
   `conf/autostart-local.lua`.
6. **Navegador predeterminado** (chromium se instala para las WebApps):
   `xdg-settings set default-web-browser firefox.desktop` (ver [docs/SYSTEM.md](docs/SYSTEM.md#other)).
7. **Opcional:** desbloqueo facial (`yay -S howdy-git`, pon tu cámara en
   `system/etc/howdy/config.ini` y luego `sudo howdy add`), Secure Boot con `sbctl` y snapshots (ver
   [docs/SYSTEM.md](docs/SYSTEM.md#snapshots-and-updates)).
8. **Actualiza** desde el menú (Actualizar) o Ajustes → Actualizaciones: ejecuta `arch-update`, que
   hace antes una snapshot.

## Cómo está organizado

Cada archivo vive **una sola vez**, en este repo, y en `$HOME` hay enlaces simbólicos: se edita en
su sitio de siempre y el cambio ya está en el repo.

| Ruta | Qué es |
|---|---|
| `home/` | Todo lo que se enlaza en `$HOME` (lista en `links.txt`) |
| `home/.config/hypr/` | Hyprland modular (`hyprland.lua` + `conf/`); `conf/shell-settings.lua`, `conf/theme.lua` e `hypridle.conf` son generados (fuera de git) |
| `home/.config/quickshell/` | El shell; su `CLAUDE.md` es la guía de diseño y de las trampas de QML |
| `home/.config/walker/`, `home/.config/elephant/` | Lanzador (tema `nothing`, sobre el de Omarchy), sus proveedores y menús Lua |
| `home/.config/alacritty/`, `bash/`, `fastfetch/`, `gtk-3.0/`, `gtk-4.0/`, `nvim/plugin/clipboard.lua` | Terminal, prompt (con `ls`/`eza` en color), fetch, paleta GTK y portapapeles de nvim |
| `home/.local/bin/` | Scripts: `menu` (menú del sistema), `screenshot`, `record`, `packages`, `webapp`, `tui`, `lock-screen`, `share-picker`, `menu-keybinds`… |
| `home/.local/share/` | Fuente Doto (OFL) y el tema GTK «NothingOS» (adw-gtk3-dark renombrado) |
| `home/.claude/skills/system/` | Skill de agente para arreglar y configurar esta instalación |
| `system/` | **Copias y plantillas** de archivos del sistema: greetd, PAM, Howdy, Limine, mkinitcpio, splash de la UKI, parche de audio del G14, `arch-update`, hook de pacman y estado de ALSA |
| `installer/`, `install.sh` | El instalador |
| `packages.txt`, `packages-aur.txt`, `links.txt` | Paquetes (repositorios y AUR, cada uno con su comentario) y las rutas que se enlazan |
| `features.txt` | Funciones opcionales (paquetes, servicios, archivos de sistema) que el módulo `features` te deja quitar |
| `scripts/` | Generador del logo de arranque (`boot-logo.py`) y migración de btrfs a snapshots (`snapshots-setup.sh`) |
| `private/` | Tus archivos, fuera de git (abajo) |
| `docs/` | Documentación (abajo) |

### Los datos privados no van en git

Nada personal ni propio de un equipo va en el repo:

- Los archivos de `system/` que necesitan datos del equipo son **plantillas** (`@USER@`, `@HOME@`,
  `@MACHINE_ID@`, `@ROOT_PARTUUID@`) que el instalador rellena en el equipo donde se ejecuta.
  `/etc/fstab` no se gestiona.
- Los ajustes del shell (`home/.config/quickshell/settings.json`) y todo lo que se genera a partir
  de ellos (`conf/shell-settings.lua`, `hypridle.conf`, `xdph.conf`, colores del tema) están en
  `.gitignore`; el shell los escribe al arrancar.
- **`private/`** (ignorada por git) guarda lo tuyo: `private/home/…` se enlaza en `$HOME` igual que
  `home/…`. Ahí va lo que no se puede redistribuir, como el cursor Windows 11 Fluent (sin él se usa
  XCursor-Pro, que es libre). Si existe un `private/MACHINE.md` con notas de tu equipo, la skill de
  agente lo lee.

## Documentación

La documentación está en inglés.

| Documento | Qué cuenta |
|---|---|
| [`docs/HYPRLAND.md`](docs/HYPRLAND.md) | Config modular de Hyprland, **atajos** y escalado de apps X11 |
| [`docs/QUICKSHELL.md`](docs/QUICKSHELL.md) | El shell: barra, pantalla de bloqueo, Ajustes, temas, brillo, IPC e idioma |
| [`docs/WALKER.md`](docs/WALKER.md) | Lanzador, menú del sistema, capturas, grabación, paquetes, WebApps y TUIs |
| [`docs/SYSTEM.md`](docs/SYSTEM.md) | Aspecto, login, Limine, arranque silencioso, snapshots y `arch-update`, Secure Boot y Howdy |
| [`docs/HARDWARE.md`](docs/HARDWARE.md) | Notas para el ASUS ROG Zephyrus G14 (GA403) y portátiles híbridos AMD + NVIDIA; qué cambiar en otros equipos |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | Historial: cambios, arreglos, pruebas y temas pendientes |
| [`home/.claude/skills/system/`](home/.claude/skills/system/) | Skill de Claude Code para arreglar y cambiar esta configuración documentándolo en `docs/` |

## Créditos

- [Omarchy](https://github.com/basecamp/omarchy) (MIT): tema de walker y diseño del menú del sistema.
- [illogical-impulse / end-4 dots](https://github.com/end-4/dots-hyprland): inspiración del shell y del instalador.
- [Doto](https://fonts.google.com/specimen/Doto) (OFL), [XCursor-pro](https://github.com/ful1e5/XCursor-pro), [adw-gtk3](https://github.com/lassekongo83/adw-gtk3), [esquemas base16 de tinted-theming](https://github.com/tinted-theming/schemes).
- Estética inspirada en Nothing OS. Sin relación con Nothing Technology.

## Licencia

[MIT](LICENSE), salvo las piezas de terceros incluidas, que mantienen su licencia (Doto: OFL,
junto a la fuente).
