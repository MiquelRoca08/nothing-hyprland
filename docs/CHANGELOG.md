# Changelog

History of the setup: what changed, what broke and what was tried. The guides in this folder
describe how things work **now**; this file keeps the past, grouped by area, for when a problem
comes back or a decision needs its background. Dates are from September 2026.

## Repository

- **29 Sep — Everything renamed to English.** Files, commands and data that had Spanish names now
  use English ones:
  - Installer: `instalar/` → `installer/`, modules `10-packages`, `20-aur`, `30-services`,
    `40-links`, `50-appearance`, `60-system`, `70-boot`, `80-login`; `paquetes*.txt` →
    `packages*.txt`, `enlaces.txt` → `links.txt`; `privado/` → `private/` (the `links` module
    renames the old folder if it finds it).
  - `~/.local/bin`: `bloquear` → `lock-screen`, `captura` → `screenshot`, `grabar` → `record`,
    `compartir-pantalla` → `share-picker`, `menu-atajos` → `menu-keybinds`, `menu-atras` →
    `menu-back`, `paquetes` → `packages`; subcommands too (`screenshot screen|region|window|text`,
    `record --audio --mic --stop`, `webapp create|remove|open`, `tui create|remove`,
    `packages remove|remove-flatpak`, `menu run|--entries|--all-entries|--from-main`). Web app and
    TUI launchers made by older versions (`webapp abrir`, `X-Creado-Por`) still work.
  - Shell scripts: `update.sh`, `storage.sh`, `apps.sh`, `brightness.sh`, `fonts.sh`,
    `printers.sh`, `mouse.py`, `theme.sh` (`apply|list|save|remove|catalog`); `quickshell/temas/`
    → `themes/`; generated files `theme.css` / `conf/theme.lua`; data in
    `~/.local/share/quickshell/theme/current.json` and `tasks.json`. `scripts/migrate.sh` moves the
    old data on the next shell start.
  - Elephant menus `system.lua`, `systemsearch.lua`, `wallpapers.lua`; `nvim/plugin/clipboard.lua`;
    `/etc/pam.d/quickshell-lock-face`; `scripts/boot-logo.py`; the Hyprland submap `capture`;
    template placeholders `@USER@` and `@ROOT_PARTUUID@`; the agent skill `system`.
  - `scripts/snapshots-setup.sh`: `phase1|phase2|phase3|cleanup` (the old names still work as
    aliases), confirmation word `DELETE`, the temporary entry «Rescue (old root)», top level mounted
    at `/mnt/btrfs-top`, backup `limine.conf.before-snapshots`.
  - OCR no longer installs Spanish data by default: English plus any installed
    `tesseract-data-<lang>`.
  - Removed: `scripts/migrar-privado.sh` (one-off migration, done) and the `~/Documents/SYSTEM.md`
    link. The `links` and `system` modules remove the stale links and `/etc` files left behind.
- **28–29 Sep — Language support.** Shell, menus, scripts and installer moved to English source
  texts with a Spanish dictionary (`i18n/es.js`, `i18n/i18n.sh`). Menu settings saved with the old
  Spanish entry names are renamed once by `Config.migrateMenu()`.
- **Private data out of git.** Machine data became templates filled in by the installer; the
  user's own non-redistributable files moved to `private/` (git-ignored).

## Shell (Quickshell)

- **Origin.** The desktop started from illogical-impulse (end-4's dots), which was later removed
  completely in favour of an own shell: its ~1000 installed files, its cloned repo and config, the
  15 `illogical-impulse-*` metapackages and ~100 orphans. About 50 packages it had re-marked as its
  dependencies (Hyprland, NetworkManager, PipeWire, the portals…) were protected first so they
  were not removed. The official `quickshell` 0.3.1 and `adw-gtk-theme` replaced it.
- **26 Sep — Own lock screen** replaced hyprlock (kept as a fallback), with Howdy face unlock.
  Tested with `qs ipc call lock test` (face unlock in ~1.3 s).
- **27 Sep — Settings redesign:** sidebar with categories, shared components; new pages for
  Keybinds, Storage, Printers, Themes (with the base16 catalog), Wallhaven search, Fonts,
  Hyprland, Apps and DNS in Wi-Fi.
- **Brightness fix.** `brightnessctl` picked the fake `nvidia_0` backlight instead of
  `amdgpu_bl1`, so keys and slider did nothing; brightness also only reached the internal panel.
  `scripts/brightness.sh` now picks the backlight of the GPU the panel is on and uses DDC/CI for
  external monitors. The Settings slider used to spawn many `ddcutil` processes at once and slowed
  the whole system; it now sends one at a time.
- **Input options** moved from `conf/input.lua` into Settings (`settings.json` →
  `conf/shell-settings.lua`).

## Hyprland

- **Modular config.** The monolithic `hyprland.lua` was split into `conf/*.lua` modules.
- **`input.lua` fix.** The CS2 scroll rule used `o.window(...)`, an Omarchy helper that does not
  exist here, and stopped the rest of the file from loading. Now `hl.window_rule(...)`. A duplicate
  3-finger gesture was removed.
- **XWayland scaling.** With `force_zero_scaling = true` (illogical-impulse's default) X11 apps
  were tiny on the scale-2 panel. Tried and dropped: `STEAM_FORCE_DESKTOPUI_SCALING` (ignored by
  the current client), `-forcedesktopscaling` (integers only), per-monitor scaling at launch or an
  automatic restart when moving monitors (worked, but the simple option won).
- `SUPER+SHIFT+S` changed from "move to special workspace" to region capture.
- **Per-machine monitors and own autostart apps.** `conf/monitors.lua` left git (it had the
  reference laptop's `eDP-1`/`DP-9`): the `links` module creates it on each machine from the previous
  Hyprland config (`monitor=`, `monitorv2`, `hl.monitor`), the running session or a fallback rule,
  and `hyprland.lua` falls back to "preferred, auto, auto" without it. The previous config's
  `exec-once`/`exec` commands go to `conf/autostart-local.lua` (not in git), run by `autostart.lua`;
  what this desktop already provides is written commented out. Both by `installer/hypr-import.py`.
- **Emergency mode after `git pull`.** Hyprland's reload on save ran while git was rewriting
  `hyprland.lua` («cannot open …/hyprland.lua», no keybinds) and did not reload again. The repo's
  `.githooks/post-merge` (and `post-rewrite`) now run `hyprctl reload` when a pull changes
  `home/.config/hypr`; the `links` module enables them (`core.hooksPath`).
- **The interface language is the system locale.** Settings → System → Language no longer has its
  own setting (`language` in `settings.json`, with "Automatic"): it sets `LANG` in
  `/etc/locale.conf` (`scripts/locale.sh`, with `localectl`), and the shell and the scripts read it
  from that file, so they change at once. The Settings window title is now «Settings» (was
  «Ajustes», matched by `conf/rules.lua`).
- **Safe autologin and `./install.sh uninstall`.** greetd's autologin now goes through
  `/usr/local/bin/autologin-session`, which only starts Hyprland if the dotfiles' config that locks
  the session is in place: deleting the repo folder used to leave an autologin with nothing to lock
  it. New `uninstall` module (only by name): user services, links (restoring the `.bak` copies),
  autologin, `~/.bashrc` prompt line, generated theme files, gsettings, and optionally SDDM and the
  shell's data.
- **Menu entries hidden when their program is missing:** Record, Text (OCR), Flatpak and Firmware
  (`REQUIRES` in `menu`); the keybinds that still reach them notify instead of failing silently.
- **Bluetooth and Printers hidden when not installed.** Settings pages can say which package they
  need (`needs` in `Config.settingsTree`: `bluez`, `cups`); `Config` checks them with `pacman -Qq`
  and the sidebar, search and `qs ipc call settings open` use the filtered tree.
- **Bar aligned with Settings and the menu.** Clickable modules get a hover background
  (`BarHover.qml`, like `IconButton`); the active workspace, the power menu's hover and the share
  picker's selection and main button are red (`Theme.sel`) instead of white (`Theme.accent`, which
  is now only the OSD level); the bar's panels use the cards' radius (14) instead of Hyprland's
  rounding; same spacing (14) in every zone.
- **Optional features in the installer.** New first module, `features`: `features.txt` groups
  what the desktop does not need (Bluetooth, printers + Avahi, Howdy, ASUS tools, DDC/CI, Flatpak,
  WebApps, Spotify, OCR, recording, fwupd) with its packages, services and `system/` files. They
  are picked in fzf like the menu's Install / Remove (a numbered list if fzf is not installed yet). The
  ones you leave out go to `excluded-features.txt` (not in git): `packages`/`aur` skip their
  packages, `services` their services (and the i2c group for DDC/CI), `system` their files; if
  installed, their services are disabled and their packages removed with `pacman -Rns`, keeping
  any that a package outside the feature still requires. Howdy's PAM lines use `-auth`, so
  removing it does not break `sudo` or the lock screen.
- **Flatpak in `arch-update`.** The bar and Settings counted Flatpak updates, but `arch-update`
  (what the menu and Settings → Updates run) only did pacman and the AUR, so they were never
  applied and the count stayed. New step 7: `flatpak update` of the system installation (as root:
  `packages flatpak` installs with sudo, and the desktop has no polkit agent) and of the user's
  (as the user), then unused runtimes; `--no-flatpak` skips it. The Home count was also cached for
  10 minutes: `UpdateService` now checks again whenever a Settings or menu terminal finishes.
- **walker and hyprlock translated.** walker's "No results", "Restart walker" and "Search…" come
  from `config.toml.template` through `walker-config` (run by `walker.service` on start; the
  generated `config.toml` is not in git); the fallback hyprlock gets a translated copy of its
  config ("PASSWORD") and the system `LANG` from `lock-screen`.
- **`steam`, `rog-control-center` and `discord` left `conf/autostart.lua`** (they were the reference
  laptop's own apps): the repo only starts the desktop; personal apps go in `conf/autostart-local.lua`.

## Launcher and menu (walker)

- **24–25 Sep — Built in seven phases** after Omarchy 3.8.4: 0 `arch-update`; 1 walker and elephant
  config; 2 theme; 3 startup, services, `PATH` and pacman hook; 4 menu, screenshots, recording and
  wallpapers; 5 helpers; 6 keybinds; 7 verification. Later: search in the main menu, Backspace in
  submenus, fzf package installer with Flatpak, web apps and TUIs, "About", `SUPER+Escape`.
- **First failure:** walker showed "No Results" because only the `elephant-bin` core was installed,
  without providers.
- **27 Sep — Renderer.** walker used `GSK_RENDERER=cairo` (like Omarchy, to avoid NVIDIA issues),
  which left stray white dots from the previous frame when results changed. Now `ngl`.
- **28 Sep — Theme follows Settings.** Before: radius 18, hint text in Doto capitals and the
  selected entry inverted in white. Rows are fixed at 44 px (the subtitle used `font-size: 0`,
  which Pango can treat as the default size) and the main menu gets 6 px of slack (at scale 1.8
  rows could end up taller and clip the last section).
- **27 Sep — Menu editable from Settings** (hidden entries, order, custom entries).
- **30 Sep — Slow main menu.** Opening it and every keystroke waited ~150 ms: `menus/system*.lua`
  had `Cache = false`, so elephant ran `menu --entries` on each query, and that took ~135 ms (two
  `$(…)` subshells per entry for the translations, three `jq`). Now the translations read `I18N`
  directly and one `jq` reads the three lists (~30 ms), and the menus (also `wallpapers.lua`, ~18 ms)
  are cached with `RefreshOnChange` on folders (<1 ms per query). A cache in a Lua variable did not
  work (elephant does not keep the globals) and file watches were lost after an atomic save.

## Login and lock

- **SDDM black screen → greetd.** On boot the laptop panel stayed black with SDDM: it uses X11,
  and X11 picked the NVIDIA GPU (no visible outputs at boot) as primary while the panel is on the
  AMD one. An `OutputClass` with `PrimaryGPU "yes"` for the AMD GPU made it worse
  (`modeset(G0): Failed to create pixmap`, the greeter stopped accepting the password) and was
  reverted from a tty. Replaced by greetd autologin plus an immediate lock (hyprlock at first, the
  shell's lock screen since 26 Sep).

## Boot

- **28 Sep — Plymouth tried and disabled.**
  - The boot hung on the logo ("A start job is running for Hold until boot process finishes up"):
    a drop-in made greetd `Conflicts=plymouth-quit.service` while `greetd.service` is
    `After=plymouth-quit-wait.service`, so they waited for each other.
  - The logo was twice as big (HiDPI ×2); `DeviceScale=1` was not enough, it needed
    `plymouth.force-scale=1`.
  - The external monitor on the NVIDIA GPU had no picture: Hyprland's log repeated
    `drm: Cannot commit when a page-flip is awaiting`. Neither a DPMS cycle nor dropping
    `--retain-splash` helped; `plymouth.enable=0` did. `nvidia-drm` loads after the root is mounted,
    Plymouth picks the output up and leaves it in a state Hyprland does not recover from.
  - It came back later through a typo on the kernel line (`plymouth.enable)0`). Since then
    `plymouth-start.service` is also masked. The installer removes the test drop-ins
    (`greetd.service.d/plymouth.conf`, `plymouth-quit.service.d/retener.conf`).
- **29 Sep — Limine menu without branding.** Until then it showed the logo and the laptop's model
  name at the bottom and "archlinux" at the top; now only the dot grid and box. The `boot` module
  empties `interface_branding` in an existing `/boot/limine.conf`.
- **UKI splash** replaced the Arch logo (`splash-arch.bmp`) with the dot-matrix logo.

## External monitor without picture

It happened several times with different causes:

1. **23 Sep — Not detected by the kernel** (`card0-DP-9` `disconnected`, `nvidia ... Cannot find
   any crtc or sizes`): physical (cable, input or the monitor's deep sleep).
2. **24 Sep — Detected, no picture**, no errors in Hyprland's log. A DPMS off/on cycle made the
   link renegotiate (see [HARDWARE.md](HARDWARE.md)).
3. **28 Sep — Plymouth** (see Boot).

## Snapshots and updates

- **btrfs migration.** The root used to be the whole volume without subvolumes;
  `scripts/snapshots-setup.sh` moved it to `@`/`@home` in phases. The first run of phase 1 was
  interrupted (`rm --one-file-system` does not delete nested subvolumes); running it again redid
  the half-made subvolumes.
- **24 Sep — Incident in the cleanup phase.** Its first version listed the old root's nested
  subvolumes with `btrfs subvolume list -o "$TOP/<dir>"`, which for a plain directory lists the
  children of the top level, so it deleted `@home` while mounted (`findmnt /home` showed
  `[/@home//deleted]`, new writes became 0-byte files). Recovered by creating a new `@home` and
  copying the still-mounted home into it; a few caches written in between were lost. The script now
  lists every subvolume once, keeps only those under the old root by path, shows them before asking
  and aborts on `@`, `@home`, anything inside them or anything mounted. The temporary rescue boot
  entry (which could no longer boot a half-deleted old root) was removed by hand afterwards.
- **Snapshots piled up.** An earlier `arch-update` created snapshots without `-c number` and
  without `cleanup`, so they accumulated (with their Limine entries). Fixed; remove leftovers with
  `sudo snapper -c root delete <n>`.
- **27 Sep — Limine left unsigned** (`BOOTX64.EFI`, `BOOTIA32.EFI`) after the first real
  `arch-update`, with no package updated: something rewrote it without going through
  `zz-sbctl.hook` (suspect: limine-snapper-sync or limine-entry-tool while creating the snapshot,
  unconfirmed). `arch-update` and `snapshot.sh` now run `sbctl sign-all` when they see unsigned
  files.
- **27 Sep — `arch-update` questions became buttons**, and `--menu` mode (waits for a Close button,
  exits with 200).

## Hardware and system (see [HARDWARE.md](HARDWARE.md))

- **G14 audio.** The speakers sounded muffled and volume keys did nothing; a wired headset's mic did
  not show up. A first fix, WirePlumber's `api.alsa.soft-mixer` with the hardware mixer fixed at
  100 %, broke headphones (the "Headphone" control stayed at 0) and was removed in favour of the
  kernel quirk applied through a driver patch.
- **26 Sep — Face unlock in `sudo`** (Howdy); `dark_threshold` raised to 95 because enrolment
  failed with "All frames were too dark". `howdy` 2.6.1 and `howdy-beta-git` were dropped for
  `howdy-git`.
- **26 Sep — Default browser.** After installing chromium (for web apps) it started opening links
  and PDFs: with no saved preference xdg takes the first entry of `mimeinfo.cache`, which is
  alphabetical. Firefox is now set explicitly.
- **28 Sep — Nautilus "ServiceUnknown"** when opening a drive's properties externally: the button
  calls Disks over D-Bus; `gnome-disk-utility` added to `packages.txt`.
- **Cursor:** Bibata-Modern-Ice → XCursor-Pro-Dark → Win11-Fluent-Dark (26 Sep, from `private/`).
  Its hand cursor had no 64 px size, so at scale 2 it looked 25 % smaller than the arrow; a 64 px
  one was made by downscaling the 96 px one (27 Sep). Cursor size went from 24 to 32.
- **27 Sep — UI font** NotoSans Nerd Font → JetBrainsMono Nerd Font; Alacritty palette with red
  accents and muted colours; new bash prompt.

## Open items

Things not yet verified on real hardware:

- Face unlock after opening the lid (should search without pressing anything), the "face not
  recognized" message with the camera covered, and retry after an idle lock.
- Connecting to new networks from Settings (open and 802.1X/eduroam) and pairing Bluetooth devices
  with real clicks.
- A real resolution/position change in Settings → Displays confirmed with "Keep".
- Every Settings page, the menu and the wallpaper picker in both languages after the move to
  `I18n.tr`; hidden menu entries and section order surviving the rename.
- The menu theme on the machine: no clipped sections, no CSS warnings in
  `journalctl --user -u walker -b`.
- Creating and opening a web app.
- The external monitor keeps its picture across reboots with `plymouth-start.service` masked.
- A full real update with the current `arch-update`.
