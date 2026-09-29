# nothing-hyprland

A monochrome, Nothing OS–inspired Arch Linux desktop: **Hyprland 0.56 (Lua config)**, a custom
**Quickshell** shell (bar, notifications, OSD, lock screen, a full Settings app) and a **walker**
launcher/system menu, with a themed boot (Limine + UKI) and an interactive installer.

> [!NOTE]
> Built on an **ASUS ROG Zephyrus G14 (GA403)**: AMD iGPU + NVIDIA dGPU, a 2880×1800 panel and an
> external 1440p monitor. The desktop (`home/`) works on any Arch + Hyprland machine; a few
> `system/` files and defaults are tied to that laptop. [`docs/HARDWARE.md`](docs/HARDWARE.md)
> lists them and what to adjust on other hardware. Read the installer's prompts before saying yes.

*[Leer en español](README.es.md)* · Docs and code comments are in English; the shell's UI is in
English or Spanish (Settings → System → Language).

## Screenshots

<!-- screenshots: docs/img/desktop.png, docs/img/settings.png, docs/img/menu.png, docs/img/lock.png -->

Screenshots of the desktop, the Settings app, the system menu and the lock screen will go here.

## Highlights

- **Quickshell shell** (`home/.config/quickshell/`): bar with draggable modules, notification
  center, OSD, power menu, screen-share picker with live previews, lock screen with PAM and face
  unlock (Howdy), and a **Settings app**: displays (drag-to-arrange layout), sound, Wi-Fi (with
  custom DNS), Bluetooth, printers (CUPS + avahi discovery), keyboard/mouse, keybinds editor,
  storage cleanup, apps (installed / install from pacman, AUR, Flatpak, web apps, TUIs), fonts,
  wallpapers (with Wallhaven search), **desktop-wide themes** (including the whole base16 catalog),
  updates with snapshots, and more.
- **Themes that reach everything:** one theme recolors the shell, Alacritty, walker, GTK 3/4 apps
  and Hyprland borders.
- **walker** launcher and an Omarchy-style **system menu** (`SUPER+SPACE`), configurable from
  Settings.
- **Quiet boot:** a clean Limine menu and a UKI splash with a dot-matrix «NOTHING OS LINUX» logo, no
  console text; Secure Boot with sbctl; btrfs snapshots in the boot menu (snapper + limine-snapper-sync).
- **Interactive, modular installer:** every action shows the exact command and asks before running
  it.

## Requirements

- **Arch Linux** (x86_64), installed and booting, with a user that can use `sudo`, a network
  connection and `git`. Run the installer as that user, from a terminal (not as root).
- **UEFI**, with the EFI system partition mounted at **`/boot`** (about 1 GiB: the unified kernel
  image is ~170 MiB and each snapshot may keep its own copy).
- The **`linux`** kernel (the UKI preset is `/etc/mkinitcpio.d/linux.preset`) and your **GPU
  drivers** (not in `packages.txt`; e.g. `nvidia-open` + `nvidia-utils` for NVIDIA).
- **Limine** as the boot loader. The installer writes its config (`/boot/limine.conf`) but does not
  install Limine to the ESP or create the firmware boot entry.
- **btrfs recommended**, with the root in a `@` subvolume and home in `@home`: the Limine template
  boots `rootflags=subvol=/@`, and snapshots need it. A plain btrfs root can be migrated with
  `scripts/snapshots-setup.sh` ([docs/SYSTEM.md](docs/SYSTEM.md#setting-up-snapshots-on-an-existing-btrfs-root)).
  With another filesystem, edit `system/boot/limine.conf` before running the `system` module and
  skip the snapshot parts.
- **Optional:** Secure Boot (you create and enroll the keys with `sbctl`), an IR camera for face
  unlock (Howdy), a DDC/CI-capable external monitor for brightness control.

## Install

```sh
git clone https://github.com/MiquelRoca08/nothing-hyprland.git ~/dotfiles
cd ~/dotfiles
./install.sh          # every module, asking before each action
```

`./install.sh` runs the modules in [`installer/`](installer/) in order. Each one explains what it
does and, **before every action, shows the exact command and asks** (like the illogical-impulse
installer):

- `y` (or Enter): yes.
- `n`: no — skip the rest of this module and go on with the next one.
- `yall`: yes to everything, no more questions (unless something fails).
- `q`: quit.

If a command fails it always asks: retry, continue, skip the module or quit. A summary is printed
at the end. Every module only does what is missing, so it is safe to run again after a `git pull`.

| Module | What it does |
|---|---|
| `packages` | `pacman -Syu --needed` with [`packages.txt`](packages.txt) (also updates the system); lists every package with its size and the total first |
| `aur` | `yay -S --needed` with [`packages-aur.txt`](packages-aur.txt); builds yay first if missing |
| `services` | Enables NetworkManager, bluetooth, power-profiles-daemon, cups and avahi; adds you to the `i2c` group |
| `links` | Symlinks the paths in [`links.txt`](links.txt) from `home/` (or `private/home/`) into `$HOME`; existing files are backed up as `.bak-<date>`; removes links left by renamed files. Before replacing an existing `~/.config/hypr` it keeps its monitors and autostart apps (see [below](#your-previous-hyprland-config)); enables the repo's git hooks (`.githooks/`: reload Hyprland after a `git pull` that changes its config) |
| `appearance` | Bash prompt, theme colors, fallback cursor, gsettings, walker/elephant user services and `xdph.conf` |
| `system` | Copies the changed files of `system/` to `/`, filling the templates with this machine's data |
| `boot` | Kernel options in `/boot/limine.conf`, Plymouth masked, `mkinitcpio -P` when needed |
| `login` | greetd autologin instead of SDDM |

Run only some by name: `./install.sh links system boot`. `./install.sh -h` lists the modules with
their descriptions. It speaks English or Spanish, following `$LANG`; `--lang en|es` forces it
(`./install.sh --lang es`).

A new module is a file `installer/NN-name.sh` with `TITLE`, `DESCRIPTION` and a `module()` function
that runs each action through `step "what it does" command…` (`installer/lib.sh`); its texts go
through `t "English text"`, with the Spanish in `home/.config/quickshell/i18n/es.js`.

### Your previous Hyprland config

The `links` module replaces `~/.config/hypr` with the repo's modular Lua config (the old folder is
kept as `~/.config/hypr.bak-<date>`). It does not merge the rest of your old config, but before
replacing it, it keeps two things, written to files that are yours and not in git
([`installer/hypr-import.py`](installer/hypr-import.py)):

- **Monitors → `conf/monitors.lua`.** The `monitor =` / `monitorv2` rules of a `hyprland.conf`
  (following `source =`) or the `hl.monitor` rules of a Lua config. If there are none, the monitors as
  the running Hyprland session has them. A fallback rule for any other monitor (preferred mode,
  automatic position and scale) is always added. Settings → Displays rewrites this file later.
- **Autostart apps → `conf/autostart-local.lua`.** The `exec-once` / `exec` commands (or
  `hl.exec_cmd` calls), as a list that `conf/autostart.lua` runs on start. What this desktop already
  does (bar, notifications, wallpaper, idle, lock, launcher, clipboard…) is written commented out,
  with the reason, so two bars or two notification daemons do not fight. Rules such as
  `[workspace 2 silent]` are dropped (noted in a comment).

Without a previous config, `conf/monitors.lua` is still created (from the running session or with
the fallback rule only). Both files are only written if they do not exist yet: edit them freely.

## First steps after installing

1. **Reboot.** greetd logs you in and the lock screen appears at once: unlock with your password.
   If the `i2c` group was added, this also applies it.
2. **Keybinds:** `SUPER+K` lists them all, `SUPER+SPACE` opens the system menu, `SUPER+I` opens
   Settings. The main ones are in [docs/HYPRLAND.md](docs/HYPRLAND.md#keybinds).
3. **Displays:** the `links` module created `conf/monitors.lua` for your machine (from your previous
   Hyprland config, the running session or, failing both, every monitor at its preferred mode). Fine-tune
   it in Settings → System → Displays: arrange your monitors, pick resolution and scale, and Apply
   (you get 15 s to Keep).
4. **Look:** Settings → Personalization → Wallpaper and Themes; Settings → System → Language.
5. **Hardware check:** read [docs/HARDWARE.md](docs/HARDWARE.md) and remove what does not apply
   (e.g. `asusctl`/`rog-control-center`, the G14 audio patch). Your own autostart apps go in
   `conf/autostart-local.lua`.
6. **Default browser** (chromium is installed for web apps):
   `xdg-settings set default-web-browser firefox.desktop` (see [docs/SYSTEM.md](docs/SYSTEM.md#other)).
7. **Optional:** face unlock (`yay -S howdy-git`, set your camera in `system/etc/howdy/config.ini`,
   then `sudo howdy add`), Secure Boot with `sbctl`, and snapshots (see
   [docs/SYSTEM.md](docs/SYSTEM.md#snapshots-and-updates)).
8. **Update** from the menu (Update) or Settings → Updates: it runs `arch-update`, which takes a
   snapshot first.

## How it is organized

Every file lives **once**, in this repo, and `$HOME` gets symlinks: you edit files where they
always were and the change is already in the repo.

| Path | What it is |
|---|---|
| `home/` | Everything linked into `$HOME` (list in `links.txt`) |
| `home/.config/hypr/` | Modular Hyprland config (`hyprland.lua` + `conf/`); `conf/shell-settings.lua`, `conf/theme.lua` and `hypridle.conf` are generated (not in git) |
| `home/.config/quickshell/` | The shell; `CLAUDE.md` there is the guide to its design rules and known QML pitfalls |
| `home/.config/walker/`, `home/.config/elephant/` | Launcher (theme `nothing`, based on Omarchy's) and its providers and Lua menus |
| `home/.config/alacritty/`, `bash/`, `fastfetch/`, `gtk-3.0/`, `gtk-4.0/`, `nvim/plugin/clipboard.lua` | Terminal, prompt (with colored `ls`/`eza`), fetch, GTK palette and nvim clipboard |
| `home/.local/bin/` | Scripts: `menu` (system menu), `screenshot`, `record`, `packages`, `webapp`, `tui`, `lock-screen`, `share-picker`, `menu-keybinds`… |
| `home/.local/share/` | Doto font (OFL) and the «NothingOS» GTK theme (adw-gtk3-dark renamed) |
| `home/.claude/skills/system/` | An agent skill for fixing and configuring this setup |
| `system/` | **Copies/templates** of system files: greetd, PAM, Howdy, Limine, mkinitcpio, UKI splash, G14 audio patch, `arch-update`, pacman hook, ALSA state |
| `installer/`, `install.sh` | The installer |
| `packages.txt`, `packages-aur.txt`, `links.txt` | Packages (repos and AUR, each with a comment) and the paths to link |
| `scripts/` | Boot logo generator (`boot-logo.py`) and btrfs snapshot migration (`snapshots-setup.sh`) |
| `private/` | Your own files, not in git (below) |
| `docs/` | Documentation (below) |

### Private data stays out of git

Anything personal or machine-specific is **not** in the repo:

- `system/` files that need machine data are **templates** (`@USER@`, `@HOME@`, `@MACHINE_ID@`,
  `@ROOT_PARTUUID@`) that the installer fills in on the machine it runs on. `/etc/fstab` is not
  managed.
- The shell's settings (`home/.config/quickshell/settings.json`) and everything generated from
  them (`conf/shell-settings.lua`, `hypridle.conf`, `xdph.conf`, theme colors) are in
  `.gitignore`; the shell writes them on startup.
- **`private/`** (git-ignored) holds your own files: `private/home/…` is linked into `$HOME` just
  like `home/…`. Put non-redistributable things there, like the Windows 11 Fluent cursor (without
  it, the free XCursor-Pro is used). A `private/MACHINE.md` with notes about your machine is read
  by the agent skill if present.

## Documentation

| Document | Contents |
|---|---|
| [`docs/HYPRLAND.md`](docs/HYPRLAND.md) | Modular Hyprland config, **keybinds**, X11 app scaling |
| [`docs/QUICKSHELL.md`](docs/QUICKSHELL.md) | The shell: bar, lock screen, Settings, themes, brightness, IPC, language |
| [`docs/WALKER.md`](docs/WALKER.md) | Launcher, system menu, screenshots, recording, packages, web apps and TUIs |
| [`docs/SYSTEM.md`](docs/SYSTEM.md) | Look and feel, login, Limine, quiet boot, snapshots and `arch-update`, Secure Boot, Howdy |
| [`docs/HARDWARE.md`](docs/HARDWARE.md) | Notes for the ASUS ROG Zephyrus G14 (GA403) and hybrid AMD + NVIDIA laptops; what to adjust elsewhere |
| [`docs/CHANGELOG.md`](docs/CHANGELOG.md) | History: changes, fixes, experiments and open items |
| [`home/.claude/skills/system/`](home/.claude/skills/system/) | A Claude Code skill to fix and change this setup while keeping `docs/` up to date |

## Credits

- [Omarchy](https://github.com/basecamp/omarchy) (MIT): walker theme and system menu design.
- [illogical-impulse / end-4 dots](https://github.com/end-4/dots-hyprland): inspiration for the shell and the installer.
- [Doto](https://fonts.google.com/specimen/Doto) (OFL), [XCursor-pro](https://github.com/ful1e5/XCursor-pro), [adw-gtk3](https://github.com/lassekongo83/adw-gtk3), [tinted-theming base16 schemes](https://github.com/tinted-theming/schemes).
- Visual language inspired by Nothing OS. Not affiliated with Nothing Technology.

## License

[MIT](LICENSE), except the bundled third-party pieces, which keep their own licenses (Doto: OFL,
included next to the font).
