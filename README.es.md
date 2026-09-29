# nothing-hyprland

Un escritorio Arch Linux monocromo inspirado en Nothing OS: **Hyprland 0.56 (config en Lua)**, un
shell propio de **Quickshell** (barra, notificaciones, OSD, pantalla de bloqueo y una app de
Ajustes completa) y un lanzador y menú del sistema con **walker**, con arranque temático (Limine +
UKI) y un instalador interactivo.

> [!NOTE]
> Hecho y probado en un **ASUS ROG Zephyrus G14 (GA403GM)**: gráfica integrada AMD + NVIDIA,
> pantalla de 2880×1800 y un monitor externo de 1440p. La parte del escritorio (`home/`) funciona en
> cualquier Arch con Hyprland; algunos archivos de `system/` (parche de audio del G14, ruta de la
> cámara IR de Howdy, Secure Boot y la disposición de Limine) son de este portátil: lee lo que
> pregunta el instalador antes de decir que sí.

*[Read in English](README.md)* · La documentación y los comentarios del código están en inglés; la
interfaz del shell, en inglés o en español (Ajustes → Sistema → Idioma).

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

## Instalar

```sh
git clone https://github.com/MiquelRoca08/nothing-hyprland.git ~/dotfiles
cd ~/dotfiles
./install.sh          # todos los módulos, preguntando antes de cada acción
```

`./install.sh` recorre los módulos de [`instalar/`](instalar/) en orden. Cada uno explica qué hace
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
| `paquetes` | `pacman -Syu --needed` con [`paquetes.txt`](paquetes.txt) (de paso actualiza el sistema); antes lista cada paquete con lo que ocupa y el total |
| `aur` | `yay -S --needed` con [`paquetes-aur.txt`](paquetes-aur.txt); si no hay yay, lo instala |
| `servicios` | NetworkManager, bluetooth, power-profiles-daemon, cups, avahi y el grupo `i2c` |
| `enlaces` | Enlaza en `$HOME` las rutas de `enlaces.txt` (lo que ya exista se guarda como `.bak-<fecha>`) |
| `aspecto` | Prompt de bash, colores del tema, cursor de respaldo, gsettings, servicios de walker/elephant y `xdph.conf` |
| `sistema` | Copia a `/` los archivos de `system/` que han cambiado, rellenando las plantillas con los datos de este equipo |
| `arranque` | Opciones del kernel en `/boot/limine.conf`, Plymouth enmascarado y `mkinitcpio -P` si hace falta |
| `login` | Autologin con greetd en vez de SDDM |

Solo algunos: `./install.sh sistema arranque`. `./install.sh -h` lista los módulos con su
descripción. Habla inglés o español según `$LANG` (`./install.sh --lang es` lo fuerza). Un módulo
nuevo es un archivo `instalar/NN-nombre.sh` con `TITULO`, `DESCRIPCION` y una función `modulo()`
que hace cada acción con `paso "qué hace" comando…` (`instalar/lib.sh`); sus textos pasan por
`t "texto en inglés"`, con el español en `home/.config/quickshell/i18n/es.js`.

Desbloqueo facial en la pantalla de bloqueo: `howdy-git` (AUR) y después `sudo howdy add`.

## Cómo está organizado

Cada archivo vive **una sola vez**, en este repo, y en `$HOME` hay enlaces simbólicos: se edita en
su sitio de siempre y el cambio ya está en el repo.

| Ruta | Qué es |
|---|---|
| `home/` | Todo lo que se enlaza en `$HOME` (lista en `enlaces.txt`) |
| `home/.config/hypr/` | Hyprland modular (`hyprland.lua` + `conf/`); `conf/shell-settings.lua` e `hypridle.conf` los genera el shell con tus ajustes (fuera de git) |
| `home/.config/quickshell/` | El shell; su `CLAUDE.md` es la guía de diseño y de las trampas de QML |
| `home/.config/walker/`, `home/.config/elephant/` | Lanzador (tema `nothing`, sobre el de Omarchy), sus proveedores y menús Lua |
| `home/.config/alacritty/`, `bash/`, `fastfetch/`, `gtk-3.0/`, `gtk-4.0/`, `nvim/plugin/` | Terminal, prompt (con `ls`/`eza` en color), fetch, paleta GTK y portapapeles de nvim |
| `home/.local/bin/` | Scripts: menú del sistema, capturas, grabación, paquetes, WebApps, TUIs, bloqueo y selector de compartir pantalla |
| `home/.local/share/` | Fuente Doto (OFL) y el tema GTK «NothingOS» (adw-gtk3-dark renombrado) |
| `system/` | **Copias y plantillas** de archivos del sistema: greetd, PAM, Howdy, Limine, mkinitcpio, splash de la UKI, parche de audio del G14, `arch-update`, hook de pacman y estado de ALSA |
| `instalar/`, `install.sh` | El instalador |
| `paquetes.txt`, `paquetes-aur.txt` | Paquetes (repositorios y AUR), cada uno con su comentario |
| `scripts/` | Generador del logo de arranque, migración de btrfs a snapshots y migración de los datos privados |
| `docs/` | Documentación (abajo) |

### Los datos privados no van en git

Nada personal ni propio de un equipo va en el repo:

- Los archivos de `system/` que necesitan datos del equipo son **plantillas** (`@USUARIO@`,
  `@HOME@`, `@MACHINE_ID@`, `@PARTUUID_RAIZ@`) que `install.sh` rellena en el equipo donde se
  ejecuta. `/etc/fstab` no se gestiona.
- Los ajustes del shell (`home/.config/quickshell/settings.json`) y todo lo que se genera a partir
  de ellos (`conf/shell-settings.lua`, `hypridle.conf`, `xdph.conf`, colores del tema) están en
  `.gitignore`; el shell los escribe al arrancar.
- `privado/` (ignorada por git) guarda lo tuyo: `privado/home/…` se enlaza en `$HOME` igual que
  `home/…`. Ahí va lo que no se puede redistribuir, como el cursor Windows 11 Fluent que se usa aquí
  (sin él, se usa XCursor-Pro, que es libre).
- Si vienes del repo privado anterior: `scripts/migrar-privado.sh` guarda en `privado/` lo que el
  repo ya no lleva, sacándolo del historial.

## Documentación

| Documento | Qué cuenta |
|---|---|
| [`docs/HYPRLAND.md`](docs/HYPRLAND.md) | Config modular de Hyprland, **atajos** y escalado de apps X11 |
| [`docs/QUICKSHELL.md`](docs/QUICKSHELL.md) | El shell: barra, notificaciones, OSD, Ajustes y brillo |
| [`docs/WALKER.md`](docs/WALKER.md) | Lanzador, menú del sistema, capturas, grabación, paquetes, WebApps y TUIs |
| [`docs/SYSTEM.md`](docs/SYSTEM.md) | Hardware, audio, login, Limine, arranque silencioso, snapshots, Secure Boot, Howdy y arreglos (también en `~/Documents/SYSTEM.md`) |
| [`home/.claude/skills/sistema/`](home/.claude/skills/sistema/) | Skill de Claude Code para arreglar y cambiar esta configuración documentándolo en `docs/` |

## Créditos

- [Omarchy](https://github.com/basecamp/omarchy) (MIT): tema de walker y diseño del menú del sistema.
- [illogical-impulse / end-4 dots](https://github.com/end-4/dots-hyprland): inspiración del shell y del instalador.
- [Doto](https://fonts.google.com/specimen/Doto) (OFL), [XCursor-pro](https://github.com/ful1e5/XCursor-pro), [adw-gtk3](https://github.com/lassekongo83/adw-gtk3), [esquemas base16 de tinted-theming](https://github.com/tinted-theming/schemes).
- Estética inspirada en Nothing OS. Sin relación con Nothing Technology.

## Licencia

[MIT](LICENSE), salvo las piezas de terceros incluidas, que mantienen su licencia (Doto: OFL,
junto a la fuente).
