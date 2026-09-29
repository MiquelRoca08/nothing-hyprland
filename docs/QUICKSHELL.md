# Quickshell: the desktop shell

A custom shell built with [Quickshell](https://quickshell.org) 0.3.1: bar, notifications, OSD,
power menu, lock screen, screen-share picker, wallpaper and a Settings app. It lives in
`home/.config/quickshell/` (linked to `~/.config/quickshell`) and Hyprland starts it with `qs`.
Development guide, design rules and known QML pitfalls: `home/.config/quickshell/CLAUDE.md`.

The UI is in English or Spanish (Settings → System → Language; see [Language](#language)).

## Look

Monochrome, Nothing OS style: black, white and greys; red (`#d71921` in the Nothing theme) for
what is active or critical, and [Doto](https://fonts.google.com/specimen/Doto) (dot matrix) for the
clock and big numbers. Every colour comes from the active theme ([Themes](#themes)); fonts,
margins and radii from `Theme.qml`.

## Bar

A floating (or attached) bar on every monitor. Any module can be **dragged** to another place or
zone (left, centre, right): dragging starts after moving a few pixels with the button held, so a
normal click still works. Settings → Personalization → QuickShell → Bar shows, hides and reorders
modules and picks the style and clock.

- **Workspaces** 1–5, always visible and the same on every bar. Filled: active here; outlined:
  visible on another screen; dimmed: empty.
- **Media:** the MPRIS player. Clicking the title opens a panel with cover art, progress, controls
  and, when several apps are playing, which one to control.
- **Date and time**, collapsible **tray**, **Wi-Fi** (opens a panel with the networks).
- **System monitor 󰍛:** click opens `btop` in a floating terminal (class `TUI.float`); the tooltip
  shows CPU, RAM and GPU usage. On a hybrid laptop the dGPU is only queried with `nvidia-smi`
  when it is already awake (its runtime state is read from sysfs, which does not wake it). It only
  polls while the tooltip is visible.
- **Microphone:** click mutes/unmutes (muted shows in red), right click opens the sound panel, the
  wheel changes the input volume; muting shows the OSD.
- **Volume:** click opens the sound panel (output/input volume and device, per-app volume of the
  streams actually playing, and a link to Settings); right click mutes; the wheel moves it in steps
  of 5.
- **Battery:** tooltip with time left (or until full), power draw and, on hybrid laptops, whether
  the dGPU is active or suspended.
- **Notifications 󰂚:** click opens the history, right click toggles Do Not Disturb.
- **Settings 󰒓** and the **power button** (Lock, Log out, Suspend, Reboot, Power off).

## Notifications and OSD

- Own notification server, with popups at the top right of the focused screen, history and Do Not
  Disturb.
- OSD for volume, microphone and brightness.

## Lock screen

Big Doto clock, grey date and a rounded password field on every monitor, using the Wayland lock
protocol (`WlSessionLock`) and PAM (`PamContext`, service `/etc/pam.d/quickshell-lock`; if that is
not installed, hyprlock's, which is equivalent). Below the field come PAM messages (e.g.
faillock's "account locked") or "wrong password" in red. Esc clears the field.

- **Everything locks through `~/.local/bin/lock-screen`**: hypridle, autostart after autologin,
  the power menu, Settings and the system menu. It calls `qs ipc call lock lock` and, if the shell
  does not answer within 5 s (not running, or its config has an error), locks with **hyprlock** as
  a fallback.
- **If the shell restarts or crashes while locked:** `lock-screen` leaves the mark
  `$XDG_RUNTIME_DIR/qs-locked` (removed on unlock) and the shell locks again on startup if it finds
  it. Hyprland has `misc.allow_session_lock_restore = true` to accept that new lock; without it,
  its emergency screen would stay.
- **PAM starts by itself** on lock and on any key or mouse movement, without waiting for Enter, so
  a module that asks for nothing (face recognition) starts right away. A password typed before PAM
  asks for it is kept and handed over then. After a failure it does not retry on its own (no
  camera loop, no wasted attempts): it waits for the next key.
- **Face (Howdy):** with Howdy installed ([SYSTEM.md](SYSTEM.md#face-recognition-howdy)), PAM uses
  `/etc/pam.d/quickshell-lock-face` (face, then password) **only if the GNOME keyring is already
  unlocked**. After autologin the keyring is locked and only the password unlocks it, so the first
  unlock after boot always asks for the password (the screen says so). Howdy's messages are
  translated and shown in grey, since the password still works. After an idle lock (the face was
  tried with nobody there), any key or movement with the field empty retries it. On suspend with
  the lid closed Howdy is skipped; on wake, hypridle calls `qs ipc call lock retry`. While Howdy
  searches (about 4 s) you can type the password.
- **Suspend:** hypridle has `inhibit_sleep = 3`, which waits until the lock screen is up before
  suspending.
- **Emergency** (the shell does not let you unlock): `Ctrl+Alt+F3`, log in and run
  ```sh
  pkill -x qs; rm -f $XDG_RUNTIME_DIR/qs-locked; hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
  ```
  Go back with `Ctrl+Alt+F1`, unlock in hyprlock and restart the shell (menu → Update → Restart the
  shell). Without removing the mark, the shell would lock again on startup.
- Settings → Personalization → QuickShell → Lock screen: minutes until lock, screens off and
  suspend (with a one-line summary and a warning if the times contradict each other), "Try" (locks
  for 15 s and unlocks by itself), "Lock", and face recognition (on/off, enroll, install).

## Screen sharing

When Discord, a browser, etc. ask to share the screen, a centred window opens instead of
`hyprland-share-picker`, with three tabs (Screens, Windows, Region) and **live previews**
(`ScreencopyView`), plus a "remember this choice" switch (restore token: the app does not ask
again). Click selects, double click or Enter shares, Esc cancels, Tab switches tabs.

- **How it hooks in:** `~/.config/hypr/xdph.conf` (generated from `xdph.conf.template`) sets
  `custom_picker_binary = ~/.local/bin/share-picker`. The portal runs that script with the window
  list in `$XDPH_WINDOW_SHARING_LIST`; the script creates a FIFO, calls
  `qs ipc call sharepicker open <fifo> <list> <token>` and prints what the shell writes back:
  `[SELECTION]r/screen:<monitor>`, `…/window:<id>` or `…/region:<monitor>@x,y,w,h` (logical
  coordinates relative to the monitor; `r` = remember), or nothing to cancel.
- If the shell does not answer, the script falls back to `hyprland-share-picker`. After changing
  `xdph.conf`: `systemctl --user restart xdg-desktop-portal-hyprland`.

## Wallpaper and corners

A dark grey wallpaper with a centred dot grid (or an image), and rounded screen corners.

## Settings

`SUPER+I` opens it. A sidebar with collapsible categories (Home, System, Connections,
Personalization, Apps, Updates) that always opens on Home. Shared design: a header with the
section icon in the accent colour, cards on black, controls one shade lighter, and the accent for
what is active (current page, chosen option, switches on, primary button). Sections that are not
built yet say so.

### Home

Summary cards (pending updates, battery, used disk, network; each leads to its section), a **to-do
list** (Enter adds, the circle marks done, the trash icon deletes; stored in
`~/.local/share/quickshell/tasks.json`, outside the repo) and machine information, including the
system's age (from the first line of `/var/log/pacman.log`, or the creation date of `/`).

### System

- **Displays:** a **layout diagram** at the top (each monitor to scale at its position; the
  focused one highlighted, a white border if it has unapplied changes). Monitors can be
  **dragged**: on drop one snaps to the nearest edge without overlapping, aligns to start, centre
  or end when close, and the whole set shifts to start at 0,0. Per monitor: brightness, resolution
  and refresh rate (from its supported modes), scale (only values that give an integer logical
  size, e.g. at 2880×1800, 1.8 → 1600×1000 yes, 1.75 no), position, rotation, VRR and 10-bit
  colour. It starts from Hyprland's actual values (`hyprctl monitors`), so hand edits are
  respected. **Apply** rewrites in `conf/monitors.lua` only the `hl.monitor` blocks of connected
  monitors and reloads Hyprland; then you have **15 s to press "Keep"** or the previous file is
  restored. The rollback runs in a separate process (`$XDG_RUNTIME_DIR/monitors.lua.before` +
  `monitors-pending`), so it works even if Settings closes or the shell restarts. "Edit in nvim"
  opens the file; anything that is not `hl.monitor` in it is dropped when applying from Settings.
- **Sound:** output and microphone volume and mute; output device; a microphone test with a level
  meter and "Hear myself" (`pw-loopback`; use headphones).
- **Keyboard and mouse:** keyboard layout, what Caps Lock does (normal, Escape, Ctrl or nothing),
  Num Lock on boot; repeat delay and rate with a test field; mouse sensitivity, acceleration,
  natural scroll, left-handed, focus follows mouse; touchpad options (only if one is present): tap
  to click, natural scroll, speed, disable while typing, clickfinger, middle-click emulation,
  3/4-finger drag, tap-and-drag, drag lock; advanced: layout variant and other XKB options.
  Everything goes to `settings.json` → `conf/shell-settings.lua`; `conf/input.lua` is left for
  gestures, specific devices and per-app rules.
- **Notifications:** Do Not Disturb and history.
- **Battery:** power profile (power-profiles-daemon), battery state and, on ASUS laptops,
  `asusctl`'s charge limit (60, 80 or 100 %).
- **Storage:** every mounted disk (no virtual filesystems; a btrfs with subvolumes shows once) with
  its usage (red from 90 %); **free up space**: pacman cache (`paccache -rk1` + `-ruk0`), yay cache,
  trash (with confirmation), journal (`journalctl --vacuum-size=200M`), orphans and unused Flatpak
  runtimes (what needs sudo runs in the floating terminal and the page recalculates when it ends);
  the largest **apps** ("Manage" jumps to Apps → Installed with that app) and the **folders** of
  `~` from largest to smallest. Data from `scripts/storage.sh` (`disks`, `cleanup`, `packages`,
  `folders`, each in its own process because `du` is slow).
- **Keybinds:** the binds of `conf/keybinds.lua` (read as is: it is the source of truth), grouped by
  their `-- ## …` headings, with search. "Change" captures a new combination (see
  [HYPRLAND.md](HYPRLAND.md#keybinds)), warns if another bind uses it and refuses a plain key
  without a modifier. Binds created in a loop (workspaces) and the whole file open in nvim at
  their line.
- **Language:** English or Español: sets the system locale (see [Language](#language)).

### Connections

- **Wi-Fi:** on/off, scan, connect, disconnect, forget. Three kinds of network, from `nmcli`'s
  SECURITY field: **open** (empty or `OWE`: connect without asking), **WPA/WPA3 personal**
  (password) and **802.1X enterprise** such as eduroam (user, password and method, PEAP/MSCHAPv2 by
  default or TTLS/PAP; under "More options", anonymous identity and the server domain, which turns
  on certificate validation against the system CAs and protects against fake networks). A failed
  attempt reconnects to the best saved network. **DNS** of the current connection (Wi-Fi or
  wired): automatic (the router's), Cloudflare, Google, Quad9 or custom (validated), applied without
  disconnecting (`nmcli connection modify` + `nmcli device reapply`), optionally to every saved
  network. All the network logic is in `NetworkService.qml`, shared by the bar, the panel and
  Settings.
- **Bluetooth:** on/off, scan, pair, connect, forget.
- **Printers** (CUPS): installs `cups cups-filters ghostscript avahi nss-mdns` if missing (without
  Ghostscript nothing prints: "gstoraster filter failed") and enables the services. Printers with
  their state, default (per user), test page, resume and remove; the queue with each job's state,
  retry and cancel. Adding: network discovery with avahi (added as
  `dnssd://<name>._ipp._tcp.local/`, which survives IP changes, or by IP if `.local` does not
  resolve), USB (when CUPS allows listing it) or by address, driverless (`lpadmin -m everywhere`).
  Data from `scripts/printers.sh`.

### Personalization

- **Wallpaper:** dot grid (with its tone) or an image from `~/Pictures/Wallpapers` ("Import…"
  copies one there; each thumbnail's trash button sends it to the system trash). **Wallhaven**
  search (public API, SFW only, no key) as you type, sorted by popular, recent, random or
  relevance, with categories and a "For my screen" filter (at least the largest screen's
  resolution); "Load more" fetches 72 more. Clicking one downloads it to
  `~/Pictures/Wallpapers/wallhaven-<id>.<ext>` and sets it.
- **Themes:** see [Themes](#themes).
- **QuickShell → Menu:** the system menu as a tree: hide sections or entries, reorder the main
  menu's sections, and add **custom entries** (icon, name, command, section). Saved in
  `settings.json` (`menuHidden`, `menuOrder`, `menuCustom`); see [WALKER.md](WALKER.md#system-menu).
- **QuickShell → Lock screen** and **Bar:** see above.
- **Fonts:** installed families, each written in its own font with an editable sample, origin
  (repos, AUR, yours in `~`, system), package, files and size. "Make default" sets it system-wide:
  proportional fonts as `sans-serif` (fontconfig
  `~/.config/fontconfig/conf.d/51-default-sans-serif.conf` + GTK's `font-name`), monospaced ones as
  `monospace` (+ `monospace-font-name`). Remove (uninstalls the package, or deletes your own
  files), "Install from file" (`.ttf/.otf/.woff/.zip` → `~/.local/share/fonts`) and "Install more"
  (font packages from the repos and the AUR). Data from `scripts/fonts.sh`.
- **Hyprland:** the status (`hyprctl configerrors`, with a reload button), then `hyprland.lua` and
  every module it `require`s, in load order and nested, with the first line of its comment and an
  "Edit in nvim" button (generated ones say "View"). New modules show up by themselves.

### Apps

- **Installed:** the launcher's apps (visible `.desktop` files) with origin (repos, AUR, Flatpak,
  web app, TUI or manual), icon and size, search, sorting and an origin filter; or **all
  packages** (with an explicit/dependency filter). Uninstall asks for confirmation: pacman
  (`-Rns`) and Flatpak in the floating terminal, web apps and TUIs with `webapp remove` /
  `tui remove`.
- **Install:** searches the repos, the AUR (by popularity) and Flathub at once as you type, with an
  origin filter; installing runs in the floating terminal. Forms to create a web app (name, site,
  optional icon) or a TUI (name, command, floating or tiled, icon) with `webapp create` /
  `tui create`.
- Data from `scripts/apps.sh` (`installed`, `packages`, `search-repos|aur|flatpak`).

### Updates

Pending updates from the repos, the AUR and Flatpak **with the package list** (current → new
version; the kernel and Hyprland marked as needing a reboot), **a snapshot without updating**
(`scripts/snapshot.sh`, with an optional description; it replaces the previous one like
`arch-update`'s), and every way of updating in the floating terminal: whole system or repos only
(`scripts/update.sh` → `arch-update --menu`), AUR only, Flatpak and firmware; plus restarting the
shell and walker. See [SYSTEM.md](SYSTEM.md#arch-update).

## Themes

A theme recolours **the whole desktop**: the shell (live), Alacritty, walker, GTK apps (when they
restart; plus the light/dark `color-scheme`) and Hyprland's borders.

- A theme is a JSON: `colors` with `Theme.qml`'s tokens and `terminal` with the 16 terminal
  colours. `quickshell/themes/nothing.json` is the bundled one and the example; installed themes
  live in `~/.local/share/quickshell/themes/`.
- Settings → Personalization → Themes: installed themes with a preview, apply and delete; the
  **base16 catalog** from [tinted-theming](https://github.com/tinted-theming/schemes) (~350 schemes,
  downloaded once to `~/.cache/quickshell/base16`) with search and a dark/light filter: pick one,
  choose its **accent** among its colours, and install or install-and-apply. The 16 base16 colours
  are mapped to the shell's layers (backgrounds and greys mix background and text, the accent for
  what is active, base08 for what is critical, the terminal in base16 order). Below: gaps, window
  rounding and screen corners.
- `scripts/theme.sh` does the work:

  | Command | Effect |
  |---|---|
  | `theme.sh apply <theme.json>` | Copies it to `~/.local/share/quickshell/theme/current.json` (read live by `Theme.qml`) and generates `~/.local/share/quickshell/theme/alacritty.toml`, `~/.config/walker/themes/nothing/theme.css`, `~/.config/gtk-{3,4}.0/theme.css` and `~/.config/hypr/conf/theme.lua`; then reloads Hyprland and walker |
  | `theme.sh list` | Bundled and installed themes, and the current one |
  | `theme.sh save` | Saves the JSON on stdin as an installed theme |
  | `theme.sh remove <id>` | Deletes an installed theme |
  | `theme.sh catalog [--refresh]` | The base16 schemes |

  The generated files inside the repo are in `.gitignore`. The `appearance` installer module runs
  `apply` with the current theme (or Nothing) when they are missing.

## One source for every value

- **Gaps, rounding, keyboard, mouse and touchpad:** in `settings.json` (written by `Config.qml`, not
  in git). The shell generates `conf/shell-settings.lua` (Hyprland reloads it by itself); the idle
  times generate `hypridle.conf`. Both are regenerated on every start.
- **Data migration:** `scripts/migrate.sh` runs on every start and moves data saved under older
  file names to the current ones (it does nothing once they are migrated).

## Brightness

`scripts/brightness.sh` is used by the brightness keys, the OSD and Settings:

- `brightness.sh get [MONITOR]` and `brightness.sh set VALUE [MONITOR]` (`60%`, `5%+`, `5%-`);
  without a monitor, the focused one.
- **Internal panel:** the backlight of the GPU the eDP panel is connected to (`brightnessctl`). On
  hybrid laptops there can be a fake backlight too; the script picks the right one and adapts if
  the GPU mode changes ([HARDWARE.md](HARDWARE.md#brightness)).
- **External monitors:** DDC/CI with `ddcutil` (VCP 0x10), with the i2c bus and maximum cached
  (~0.15 s per change). Needs the setup in [SYSTEM.md](SYSTEM.md#external-monitor-brightness-ddcci).
- The Settings slider sends while you drag, one process at a time (parallel `ddcutil` calls slow
  the whole system down).

## Components

| File | What it does |
|---|---|
| `shell.qml` | Entry point |
| `Theme.qml` | Colours (from the active theme), fonts, margins and radii |
| `Config.qml`, `settings.json` | Persistent settings (not in git); generates `conf/shell-settings.lua` and `hypridle.conf`; runs `scripts/migrate.sh` |
| `ShellState.qml` | Shared state (power menu, Settings page, focused screen) |
| `I18n.qml`, `i18n/` | Translations |
| `Bar.qml`, `BarDrag.qml` | Bar and module dragging; each zone in `Config.barLayout` order |
| `Workspaces.qml`, `Clock.qml`, `Tray.qml` | Workspaces, date and time, tray |
| `Media.qml`, `MediaPanel.qml`, `MediaService.qml` | MPRIS player, its panel and which player is controlled |
| `NetworkService.qml`, `Network.qml`, `NetworkPanel.qml`, `WifiList.qml` | Network logic (nmcli), bar module, Wi-Fi panel and list |
| `SystemMonitor.qml`, `Mic.qml`, `Volume.qml`, `SoundPanel.qml`, `Battery.qml` | Bar modules |
| `SoundVolumeRow.qml`, `SoundDeviceList.qml` | Shared by the sound panel and Settings → Sound |
| `PowerButton.qml`, `PowerMenu.qml` | Power menu |
| `LockScreen.qml`, `LockSurface.qml` | Lock screen: session lock, PAM and IPC; per-monitor content |
| `SharePicker.qml`, `SharePreview.qml`, `ShareButton.qml` | Screen-share picker |
| `Notifications.qml`, `NotificationButton.qml` | Notification server and popups; the bar's bell |
| `Osd.qml` | Volume, microphone and brightness indicator |
| `Wallpaper.qml`, `ScreenCorners.qml` | Wallpaper (dots or image) and rounded corners |
| `UpdateService.qml` | Pending updates |
| `SettingsWindow.qml` + `Settings*.qml` | Settings: section tree in `Config.settingsTree`, one `Settings*.qml` per page (`SettingsSoon.qml` for unbuilt ones) |
| `SettingsPage`, `SettingsGroup`, `SettingsRow`, `Button`, `IconButton`, `ChoiceChips`, `Toggle`, `Slider`, `SliderField`, `Stepper`, `WifiField`, `Tag`, `UsageBar`, `ScrollBar`, `Terminal` | Shared building blocks (reuse them for new pages) |
| `MonitorForm.qml` | One monitor's form (Settings → Displays) |
| `scripts/` | `brightness.sh`, `theme.sh`, `update.sh`, `snapshot.sh`, `storage.sh`, `apps.sh`, `fonts.sh`, `printers.sh`, `migrate.sh`, and `mouse.py` (a virtual mouse for testing) |

### IPC

`qs ipc show` lists everything. The useful calls:

```
qs ipc call settings open <section>   # Settings on a page (home, display, wifi, bar, updates…: keys of Config.settingsTree)
qs ipc call settings toggle           # open / close Settings
qs ipc call powermenu toggle          # power menu
qs ipc call lock lock                 # lock (better: lock-screen, which has a fallback)
qs ipc call lock test                 # lock for 15 s and unlock by itself
qs ipc call lock retry                # retry face recognition
qs ipc call osd brightness            # brightness OSD (after changing it)
qs ipc call notifications dnd         # toggle Do Not Disturb, returns the new state
qs ipc call wallpaper set <path>      # image wallpaper
qs ipc call wallpaper dots            # dot-grid wallpaper
qs ipc call sharepicker cancel        # close the screen-share picker
```

Restart the shell: `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`. Its log: `qs log`.

### Dependencies

`quickshell`, `hyprland`, `networkmanager`, `brightnessctl`, `ddcutil` (with the `i2c-dev` module
and the `i2c` group), `power-profiles-daemon`, `upower`, `wireplumber`, `zenity` (file pickers),
`hyprlock` (fallback lock), `jq`, `ttf-jetbrains-mono-nerd` and the bundled Doto font; optionally
`asusctl` (charge limit) and `howdy-git` (face unlock). All in `packages.txt` except Howdy.

## Language

- The shell's texts are in English in the code, wrapped in `I18n.tr("…")` (`I18n.qml`), and
  `i18n/es.js` has the Spanish for each one.
- **The interface language is the system locale:** `LANG` in `/etc/locale.conf` (Spanish if
  `es_*`, English otherwise). `I18n.qml` watches the file and `i18n/i18n.sh` reads it on every run,
  so a change applies at once, without restarting. Settings → System → Language (English /
  Español) runs `scripts/locale.sh set en|es` in a terminal: it generates the locale if it is not
  (`/etc/locale.gen` + `locale-gen`; prefers an already generated one, else `es_ES`/`en_US`), sets it
  with `localectl set-locale` keeping the `LC_*` lines, and updates the systemd user environment.
  Apps already running, and those Hyprland starts, keep the old `LANG` until you log out and back in
  (Hyprland cannot change its environment at runtime).
- **Dates:** `I18n.locale` (`es_ES` or `en_GB`) and, for custom formats, a translatable format
  string (`I18n.tr("MMMM d, yyyy")`).
- **Values and plurals:** `I18n.tr("%1 free").arg(size)`; `I18n.trn(n, "%1 app", "%1 apps")`.
- **Same English, different Spanish:** a context, `I18n.tr("All", "apps")` → key `All|apps`.
- **Data structures in `Config.qml`** (Settings tree, bar modules) keep English labels and are
  translated where shown: `I18n` reads `Config`, so `Config` cannot call `I18n`.
- **New text:** write it in English inside `I18n.tr` and add the Spanish to `i18n/es.js` (one line
  per entry, sorted). A missing entry just shows the English. **New language:** `i18n/<code>.js`
  with the same keys, import it in `I18n.qml` and add it to `languages`.
- **Scripts (bash)** use the same dictionary through `i18n/i18n.sh`: `source` it and call
  `t "English text"` (with values: `t "WebApp created: %s" "$name"`). Used by `menu`,
  `menu-keybinds`, `screenshot`, `record`, `webapp`, `tui`, `packages`, `walker-launch`,
  `scripts/update.sh`, `scripts/snapshot.sh`, `scripts/locale.sh`, `arch-update` (as root it finds
  the dictionary in the session user's home, `I18N_HOME`) and the installer. The elephant Lua menus call it through `bash`.
  In bash, a key ending in `\n` only works with values (printf); otherwise use `echo "$(t …)"`.
- **Keybind descriptions** and `-- ## …` headings in `conf/keybinds.lua` are English and are
  translated where shown; a trailing number ("Go to workspace 3") is kept.
- **Installer:** `./install.sh --lang en|es` (default: the system locale).
- **walker and hyprlock** have no translations of their own: `walker-config` writes walker's
  `config.toml` from a template in the interface language when its service starts (`locale.sh`
  restarts it), and `lock-screen` runs the fallback hyprlock with a copy of `hyprlock.conf` whose
  placeholder is translated and with the system `LANG` (for the date).
- **Only in one language:** the Settings window title «Settings», which `conf/rules.lua` matches.
