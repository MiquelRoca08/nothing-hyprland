---
name: system
description: Fix problems and change the configuration of an Arch Linux system installed from the nothing-hyprland dotfiles (Hyprland 0.56 with a Lua config, a custom Quickshell 0.3.1 shell, walker, greetd, Limine + UKI + Secure Boot, snapper, Howdy), keeping every change in the dotfiles repo and documented in its docs/. Use it whenever the user asks to fix something in the system or desktop ("X doesn't work", "it crashes", "there's an error", "it doesn't boot") or to change a setting (keybinds, bar, Settings app, theme, monitors, menu, boot, audio, packages…), even if they do not mention the dotfiles.
---

# The system: fix and configure

An Arch Linux desktop installed from the **nothing-hyprland** dotfiles
(https://github.com/MiquelRoca08/nothing-hyprland). **Everything** you change lives in the repo
checkout (e.g. `~/dotfiles`; find it with `readlink -f ~/.config/hypr`, which points into its
`home/`), and **every** change is documented in the repo's `docs/`.

## Language

- **Answer the user in their own language** (the language they write in).
- Everything that goes into the repo is in **English**: `docs/`, README, commit messages and code
  comments (the repo is public). Shell UI texts are written in English inside `I18n.tr("…")`, with
  their Spanish in `home/.config/quickshell/i18n/es.js`; bash scripts use `t "…"` from
  `i18n/i18n.sh` with the same dictionary. Keep `README.md` and `README.es.md` in sync.

## Before touching anything: read

1. **This machine's facts.** Do not assume hardware. Read it at runtime when it matters:
   `hyprctl monitors all` (names, modes, scales), `lspci -k | grep -A3 -Ei 'vga|3d|display'`
   (GPUs and drivers), `hostnamectl` (model), `cat /proc/cmdline`, `lsblk -f`, `findmnt /`,
   `aplay -l`, `v4l2-ctl --list-devices`. If the repo has a **`private/MACHINE.md`** (git-ignored,
   the user's own notes about this machine), read it; do not copy its contents into tracked files.
   The shipped config was built on an ASUS ROG Zephyrus G14 (AMD + NVIDIA); `docs/HARDWARE.md`
   lists what is specific to it.
2. **The docs of the area** (they explain how things work and why):

   | Area | Document |
   |---|---|
   | Login (greetd), lock, boot (Limine, UKI, quiet boot, Plymouth), snapshots, `arch-update`, Secure Boot, Howdy, look and feel | `docs/SYSTEM.md` |
   | Laptop-specific parts: hybrid GPU, external monitor, audio patch, IR camera, brightness | `docs/HARDWARE.md` |
   | Hyprland: `conf/` modules, keybinds, submaps, X11 scaling | `docs/HYPRLAND.md` |
   | Quickshell shell: bar, Settings, lock screen, themes, OSD, notifications, IPC | `docs/QUICKSHELL.md` and **`home/.config/quickshell/CLAUDE.md`** (design rules, QML pitfalls, how to test) |
   | Launcher and system menu (walker, elephant, `~/.local/bin/menu` and its tools) | `docs/WALKER.md` |
   | Past fixes, experiments and open items | `docs/CHANGELOG.md` (check "Open items": the problem may already be known) |

3. **`references/diagnostics.md`**: where the logs are and which commands to use per area.
4. **The real file** before changing it, and what generates it if it is generated (below).

## Where each thing is changed

- **`home/`** is symlinked into `$HOME` (list in `links.txt`; the installer's `links` module creates
  the links). Always edit inside the repo's `home/…`: `~/.config/hypr` and friends are links to it.
  A new path under `$HOME` must be added to `links.txt`.
- **`private/`** (git-ignored) holds the user's own files: `private/home/…` is linked like
  `home/…` (e.g. a non-redistributable cursor theme). Never commit anything from it.
- **`system/`** holds **copies/templates** of files in `/` (`/etc`, `/boot`, `/usr/local`…).
  Change the repo copy and install it with `./install.sh system boot` (`boot` runs
  `mkinitcpio -P` when the initramfs is affected) or `sudo install -Dm644 system/<path> /<path>`.
  Never change only the file in `/`: the next install overwrites it. Templates use `@USER@`,
  `@HOME@`, `@MACHINE_ID@` and `@ROOT_PARTUUID@`, filled in by the `system` module: never write
  real values into them. Exceptions the installer does not overwrite: `/etc/fstab` (not managed)
  and `/boot/limine.conf` once it has snapshots (limine-snapper-sync rewrites it; edit
  `/boot/limine.conf` and also the template `system/boot/limine.conf`).
- **Packages:** `packages.txt` (repos) or `packages-aur.txt` (AUR), with a comment saying what it is
  for. A service that must be enabled goes in `installer/30-services.sh`. Something the desktop
  does not need goes in `features.txt` too (packages, services, system files), so users can leave it out. `install.sh` runs the
  modules in `installer/NN-name.sh` (`features`, `packages`, `aur`, `services`, `links`, `appearance`,
  `system`, `boot`, `login`) and asks before every action: it is for the user to run
  (`./install.sh [module…] [--lang en|es]`).
- **Own scripts:** `home/.local/bin/` (user) or `system/usr/local/bin/` (`arch-update`); shell data
  scripts in `home/.config/quickshell/scripts/`.

### Generated files: do not edit them by hand

| File | Generated by | Change instead |
|---|---|---|
| `hypr/conf/shell-settings.lua`, `hypr/hypridle.conf` | Quickshell (`Config.qml`, from `settings.json`) on every start | The option in `Config.qml` / the Settings page |
| `hypr/conf/theme.lua`, `gtk-{3,4}.0/theme.css`, `walker/themes/nothing/theme.css`, `~/.local/share/quickshell/theme/*` (`current.json`, `alacritty.toml`) | `quickshell/scripts/theme.sh apply` | The theme (`quickshell/themes/*.json`, `~/.local/share/quickshell/themes/`) or `theme.sh` |
| `hypr/xdph.conf` | the `appearance` module, from `xdph.conf.template` | The template |
| `walker/config.toml` | `~/.local/bin/walker-config` (on every `walker.service` start), from `config.toml.template` | The template, then `walker-restart` |
| `hypr/conf/monitors.lua` (per machine, not in git) | `./install.sh links` (`installer/hypr-import.py`) at first, then Settings → Displays (only the `hl.monitor` blocks of connected monitors) | Can be edited by hand, but anything that is not `hl.monitor` is lost when applying from Settings |
| `/boot/limine.conf` | limine-snapper-sync (adds the snapshots) | See above |
| Boot images (`splash.bmp`, Plymouth `logo.png`) | `scripts/boot-logo.py` | The script |

`quickshell/scripts/migrate.sh` renames data saved under old file names on shell start; if you
rename a data file, add the old name there.

## Known pitfalls (do not repeat them)

- **Hyprland 0.56 uses Lua**, not hyprlang: `hl.config({...})`, `hl.bind(...)`,
  `hl.window_rule({...})`, `hl.monitor({...})`, `require("conf.x")` / `pcall(require, "conf.x")`.
  Dispatchers too: `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'` (the classic
  `hyprctl dispatch exec qs` is an error). Hyprland reloads on save; afterwards
  `hyprctl configerrors` must print nothing. Every `hl.bind` needs `{ description = "…" }` (in
  English) or it shows as `__lua` in the keybind list. Dispatchers given arguments they do not
  understand **act on the active window** instead of failing. Do not use helpers from other setups
  (e.g. Omarchy's `o.window`): one unknown call stops the rest of the module.
- **Quickshell 0.3.1** (no `-git` APIs). Before changing QML, read
  `home/.config/quickshell/CLAUDE.md`: properties that break loading, `Flickable` swallowing
  clicks, hover `MouseArea` inside a `HoverHandler`… and the components to reuse (`SettingsPage`,
  `SettingsGroup`, `SettingsRow`, `Button`, `ChoiceChips`, `Toggle`, `SliderField`, `WifiField`,
  `IconButton`, `Terminal`…). Colours only from `Theme.qml`. "Type X unavailable" means the error
  is in X (or something X uses), not in the file that reports it.
- **Initramfs / UKI:** after changing `mkinitcpio.conf`, hooks, `/etc/mkinitcpio.d/linux.preset`,
  firmware, `modprobe.d` or Plymouth → `sudo mkinitcpio -P`. sbctl signs the UKI by itself. The UKI
  has **no embedded cmdline** (`--no-cmdline`): kernel options live in `/boot/limine.conf`.
- **Plymouth is disabled on purpose** (`plymouth.enable=0`, no hook, `plymouth-start.service`
  masked): on hybrid NVIDIA laptops it left the external monitor black
  (`Cannot commit when a page-flip is awaiting` in Hyprland's log). Do not re-enable it without
  reading "Quiet boot" in `docs/SYSTEM.md` and checking the machine's GPUs.
- **Secure Boot:** every new or rewritten `.EFI` must be signed (`sudo sbctl verify`). If it does
  not boot, disabling Secure Boot in the firmware boots as before.
- **Monitors:** read names, modes and scales from `hyprctl monitors all`; never hardcode them.
  With fractional scales, check anything that depends on pixel sizes at every scale in use.
- **Terminals from the shell:** `dash` has no `read -p`; use `Terminal.run` / `Terminal.open` (QML)
  or `bash -c`. The menu's terminal windows have class `menu-terminal`.
- **Field-separated data in scripts:** empty fields are lost with `IFS=$'\t'` (whitespace
  separators merge); use `\037`. In awk, `printf ... > 0` redirects to a file named "0": use
  parentheses.
- **`/etc/pam.d/sudo`** belongs to the `sudo` package (it carries the Howdy line): if a `.pacnew`
  arrives, the line has to be added again.
- **walker:** a `-s <set>` it does not know crashes it; `hl.dsp.send_shortcut` really pastes;
  `wtype` does not trigger Hyprland binds; walker windows grab the keyboard (warn the user before
  opening one to test). See "Pitfalls" in `docs/WALKER.md`.

## How to work

1. **Reproduce or understand the problem** from the logs (`references/diagnostics.md`), not
   blindly. If the user pastes an error or a screenshot, start there. If you need data only their
   machine has and you cannot run it, give them the exact command and say what output you expect.
2. **Find the cause**, not just the symptom: if the same bug can happen elsewhere (another
   component with the same pattern, another Settings page), fix it there too.
3. **Make the minimal change** in the repo checkout, in the style of the file (English comments, as
   dense as the surrounding ones). Keep machine-specific values out of tracked files: read them at
   runtime, use a template placeholder, or put them in `private/`.
4. **Validate before calling it done**, with what is available:
   - Bash: `bash -n script`, and run it with test data if possible.
   - Hyprland: `hyprctl configerrors`; `hyprctl reload` if needed.
   - QML: `qmllint -I . File.qml` and, to see a page, the offscreen test described in
     `quickshell/CLAUDE.md`; then restart the shell
     (`pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`) and read `qs log`.
   - System: `systemctl status <unit>`, `journalctl -b -u <unit>`, `sudo sbctl verify`.
   If you could not really test it (e.g. the boot), say so clearly and explain how to check it.
5. **Document** it in `docs/` (below). An undocumented change is not finished.
6. **Commit** from the repo checkout, in English: first line `Area: what changes`, the body says
   why (the cause of the bug). Check `git status` first and do not overwrite the user's uncommitted
   work; pull before pushing. Push only if the user works that way or asks for it.
7. **Answer** with: what was wrong and why, what you changed, how you checked it (or what you could
   not check), and the steps left for the user with copy-ready commands (usually `git pull` in the
   repo and restarting what is affected; for `system/` files, `./install.sh system boot`).

## Documenting in docs/

- **The guides describe the present.** Put the change in the area's document (table above), in the
  right section or a new `## …` one. Rewrite what is no longer true instead of stacking
  contradictory notes. Keep the "why" of non-obvious decisions (what was chosen, what was
  discarded and why) in the guide.
- **History goes to `docs/CHANGELOG.md`:** a short entry under its area with the date, the
  symptom, the cause and the fix (file and change). Things that could not be verified go to its
  "Open items"; remove them once resolved.
- **Machine-specific notes** go to `docs/HARDWARE.md` if they are about the reference hardware, or
  to `private/MACHINE.md` if they are about the user's own machine. Never put personal data
  (names, hostnames, e-mails, serials, UUIDs) in tracked files.
- A new area that fits no document → a new file in `docs/`, linked from `README.md`,
  `README.es.md` and related documents.
- If you change something the READMEs describe (repo layout, installer modules, `system/`,
  scripts), update both.
- Style: English, bullets, short sentences, paths and commands in `code`.
