# Quickshell: the desktop shell

A custom shell built with [Quickshell](https://quickshell.org) 0.3.1 (bar, notifications, OSD,
power menu, lock screen, wallpaper and a Settings window). It lives in `home/.config/quickshell/`
and Hyprland starts it with `qs`. Development guide and known pitfalls:
`home/.config/quickshell/CLAUDE.md`.

The UI is in English or Spanish (Settings → System → Language; see [Language](#language) below).

## What it does

Monochrome, Nothing OS style: black, white and greys; red (`#d71921`) for what is active or
critical, and [Doto](https://fonts.google.com/specimen/Doto) (dot matrix) for the clock and big
numbers. Every color comes from the active theme (see Themes below).

- **Floating bar** on every monitor:
  - Workspaces 1–5 always visible, the same on every bar. Filled: active here; outlined: visible on the other screen; dimmed: empty.
  - MPRIS player. Clicking the title opens a panel with cover art, progress, controls and, when several apps play (Spotify, Firefox…), which one to control.
  - Date and time.
  - Collapsible tray.
  - Wi-Fi, which opens a panel with the networks.
  - **Moving modules:** any bar icon can be grabbed and dragged elsewhere (within its zone or to the left, center or right); a line shows where it will land. A normal click still works: dragging starts after moving a few pixels with the button held.
  - System monitor 󰍛, microphone, volume, battery, Settings button 󰒓 and power button.
  - **Volume:** click opens the sound panel (like the Wi-Fi one): output and input volume and device, the volume of each app that is playing (only those actually playing: Firefox, for instance, leaves another stream open and idle) and «Más ajustes…» (more settings); right click mutes; the wheel moves it in steps of 5.
  - **Microphone:** click mutes or unmutes it (muted shows in red), right click opens the sound panel and the wheel changes the input volume. Muting or unmuting (also with the mic key) shows the OSD.
  - **System monitor 󰍛:** click opens `btop` in a floating Alacritty (class `TUI.float`); on hover, a tooltip with CPU usage (`/proc/stat`, difference between two reads), RAM (`MemTotal − MemAvailable`), the AMD GPU (`gpu_busy_percent`) and the NVIDIA one (usage and VRAM with `nvidia-smi`, **only if it is already active** according to `power/runtime_status`; while suspended it says so instead of waking it). It is read every 1.5 s only while the tooltip is visible.
  - **Battery on hover:** time left (or until full), power draw in W (UPower) and whether the NVIDIA GPU is active or suspended. The dGPU is read from `/sys/bus/pci/devices/<NVIDIA>/power/runtime_status` every 2 s only while the tooltip is visible (reading sysfs does not wake it; `nvidia-smi` does).
- **Notifications:** own server, with popups at the top right of the focused screen.
- **OSD:** volume, microphone and brightness.
- **Power menu:** Lock, Log out, Suspend, Reboot and Power off. Opens from the bar button (`SUPER+Escape` now opens the walker menu's «System» submenu instead).
- **Lock screen** (replaces hyprlock): big clock in Doto, date in grey and a rounded password field on every monitor, using the Wayland lock protocol (`WlSessionLock`) and PAM (`PamContext`, service `/etc/pam.d/quickshell-lock`; if it is not installed, hyprlock's, which is equivalent: without a PamContext service it would not start and could not unlock). The password shows on every monitor; below the field come PAM messages (e.g. faillock's «account locked») or «Contraseña incorrecta» (wrong password) in red. Esc clears the field.
  - **How locking works:** everything goes through `~/.local/bin/bloquear` (hypridle, autostart after autologin, power menu, Settings → Lock screen and the system menu). It calls `qs ipc call lock lock` and, if the shell does not answer within 5 s (not running, or its config has an error), locks with **hyprlock as a fallback** (`hyprlock.conf` is kept for that).
  - **If the shell restarts or crashes while locked:** `bloquear` leaves the mark `$XDG_RUNTIME_DIR/qs-bloqueo` (removed on unlock) and the shell, on startup, locks again if it finds it. Hyprland has `misc.allow_session_lock_restore = true` to accept that new lock; without it, its emergency screen would remain.
  - **PAM starts by itself:** on lock and on any key or mouse movement, without waiting for Enter. So a module that asks for nothing (face recognition) starts right away; a password typed before PAM asks for it is kept and handed over then. After a failure it does not retry on its own (so it does not turn the camera on in a loop or waste attempts): it waits for the next key.
  - **Face (Howdy):** with Howdy installed (see [SYSTEM.md](SYSTEM.md#face-recognition-howdy)), PAM uses `/etc/pam.d/quickshell-lock-cara` (Howdy and, if it fails, the password) **only if the GNOME keyring is already unlocked** (`busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked`). After autologin the keyring is locked and only the password unlocks it (`pam_gnome_keyring`), so the first unlock after boot always uses the password (the keyring holds the key for the browser's saved passwords and other secrets); the screen says so in grey. Howdy's (English) messages are translated; they show in grey, not red, because the password still works. On an idle lock the face is tried with nobody in front and fails: when you come back, any key or movement with the field empty retries it (if it failed more than 10 s ago). **On suspend** (closing the lid) it locks with the lid closed and Howdy is skipped (`abort_if_lid_closed`); on wake, hypridle calls `qs ipc call lock reintentar` (`after_sleep_cmd`, generated by `Config.qml`), which tries the face again (once Howdy finishes, if it was still searching). While Howdy searches you can type the password: it is handed over when PAM asks (about 4 s, Howdy's `timeout`).
  - **Suspend:** hypridle has `inhibit_sleep = 3`, which waits until the lock screen is up before suspending. With hyprlock that happened automatically (detected by the command name); with `bloquear` it has to be set.
  - **Emergency** (the shell does not let you unlock): `Ctrl+Alt+F3`, log in and run `pkill -x qs; rm -f $XDG_RUNTIME_DIR/qs-bloqueo; hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`. Go back to the session with `Ctrl+Alt+F1` (tty1), unlock in hyprlock and restart the shell (menu → restart shell). Without removing the mark, the shell would lock again on startup.
- **Screen sharing** (replaces `hyprland-share-picker`): when Discord, the browser, etc. ask to share, a centered window opens with three tabs (Screens, Windows, Region) and **live previews** (`ScreencopyView`): each monitor, each window (live on hover or when chosen; with its icon when there is no image) and the region chosen with slurp. A «Recordar esta elección» (remember) switch (restore token: the app does not ask again). Click selects, double click or Enter shares, Esc cancels, Tab switches tabs.
  - **How it hooks in:** `~/.config/hypr/xdph.conf` (generated from `xdph.conf.plantilla`) sets `custom_picker_binary = ~/.local/bin/compartir-pantalla`. The portal runs that script with the window list in `$XDPH_WINDOW_SHARING_LIST` (`<id>[HC>]<class>[HT>]<title>[HE>]<address in decimal>[HA>]`…); the script creates a FIFO, calls `qs ipc call sharepicker open <fifo> <list> <token>` and returns what the shell writes to it: `[SELECTION]r/screen:DP-9`, `…/window:<id>` or `…/region:eDP-1@x,y,w,h` (logical coordinates relative to the monitor; `r` = remember), or an empty line to cancel. Each window's preview is looked up in `Hyprland.toplevels` by address.
  - **If the shell does not answer**, the script uses `hyprland-share-picker`. After changing `xdph.conf`: `systemctl --user restart xdg-desktop-portal-hyprland`.
- **Wallpaper and corners:** dark grey wallpaper with a dot grid (centered: the same margin on every side) and rounded screen corners, like ii's "Float" option (`fakeScreenRounding`).
- **Settings window** (`SUPER+I`), redesigned on 27 Sep: a sidebar with collapsible categories (Home, System, Connections, Personalization, Apps, Updates) that always opens on **Home**. Shared design: a header with the section icon in red, `#141414` cards on black, `#1e1e1e` controls and Nothing red for what is active (current page, chosen option, switches on, primary button). Missing sections show «Próximamente» (coming soon) with what is planned.
  - **Home:** summary cards (pending updates, battery, used disk and network; each leads to its section), a **to-do list** (Enter adds, the circle marks it done, 󰆴 deletes it, «Borrar hechas» clears the done ones; in `~/.local/share/quickshell/tareas.json`, outside the repo) and machine information (including the system's age, from the first line of `/var/log/pacman.log` or, without it, the creation date of `/`).
  - **System:**
    - **Displays:** at the top, a **layout diagram** (each monitor to scale at its position and logical size, with the form's values before applying; the focused one in red, a white border if it has changes). **Monitors can be dragged**: when dropped, one snaps to the edge of the nearest one (without overlapping), aligns to its start, center or end when close, and the whole set shifts to start at 0,0; this changes the form's position and is applied with «Aplicar» (apply) like everything else. Brightness per monitor, internal and external, and the **full layout of every connected monitor**: resolution and refresh rate (from its list of supported modes), scale (only those that fit the resolution: multiples of 1/120 giving an integer logical size, e.g. at 2880×1800 1.8× → 1600×1000 yes and 1.75× no; the logical size shows below), position, rotation, VRR (off / on / fullscreen only) and 10-bit color. It starts from Hyprland's actual values (`hyprctl monitors`), so it respects hand edits. «Aplicar» rewrites in `conf/monitors.lua` **only the `hl.monitor` blocks of connected monitors** (those of disconnected ones stay as they are) and reloads Hyprland; then there are **15 s to «Mantener» (keep)** or the previous file is restored. That rollback is done by a separate process (`$XDG_RUNTIME_DIR/monitors.lua.antes` + `monitors-pendiente`), so it works even if Settings closes or the shell restarts. «Editar en nvim» opens `monitors.lua` in the floating terminal. Applying from Settings drops anything that is not `hl.monitor` in that file.
    - **Sound:** output and microphone volume and mute («Silenciar el micrófono» switch; also the bar's mic module and the XF86AudioMicMute key, with OSD); output device (speakers or HDMI); microphone test with a level meter and «Escucharme» (hear myself; pw-loopback, use headphones).
    - **Keyboard and mouse:** in groups. Keyboard: layout (chips), what Caps Lock does (normal, Escape, Ctrl or nothing: the matching XKB option) and Num Lock on boot. Repeat: delay, rate and a field to try it. Mouse: sensitivity, acceleration, natural scroll, left-handed and focus follows mouse. Touchpad (only if `hyprctl devices` sees one): tap to click, natural scroll, speed, disable while typing; and separately clickfinger, middle-click emulation, 3/4-finger drag, tap-and-drag and drag lock. Advanced: layout variant, other XKB options (text, Enter to apply) and `input.lua` in nvim. Everything goes to `settings.json` → `conf/shell-settings.lua`; the `hl.config({ input = … })` block was taken out of `conf/input.lua`, which is left only for gestures, specific devices (a Logitech M705) and per-app rules.
    - **Notifications:** Do Not Disturb and history (also from the bar's bell 󰂚: click opens the history, right click toggles Do Not Disturb).
    - **Battery:** power profile (power saver, balanced or performance), battery state and asusctl's charge limit (60, 80 or 100 %).
    - **Keybinds** (27 Sep): the ones in `conf/keybinds.lua` (read as is: it is the source of truth), grouped by their `-- ## …` headings, with search (by action or key) and keys drawn as keys. «Cambiar» (change) captures the new combination and rewrites the first argument of that `hl.bind` (Hyprland applies it on save); it warns if another bind already uses it (including the workspace loop ones) and does not allow a plain key without a modifier. While capturing, Hyprland is in the empty `captura` submap (defined at the end of `keybinds.lua`) so the combination reaches Settings instead of running; Escape or 10 s of nothing cancels. Binds created in a loop (workspaces 1–10) and the whole file open in nvim at their line.
    - **Storage** (27 Sep): every mounted disk (no virtual filesystems; a btrfs with subvolumes shows once) with its usage like `df` (red from 90 %); **free up space**: pacman cache (`paccache -rk1` + `-ruk0`), yay cache (empties `~/.cache/yay` directly, without sudo or questions; `yay -Sc` also asked about pacman's), trash (`gio trash --empty`, with confirmation), journal (`journalctl --vacuum-size=200M`), orphans and unused Flatpak runtimes (what needs sudo runs in the floating terminal; when the command ends, `Terminal.run` notifies with `qs ipc call settings changed` and the page recalculates at once); the 10 largest **apps** (pacman and Flatpak; «Gestionar» (manage) goes to Installed apps with that app in `ShellState.settingsArg`) and the **folders** of `~` from largest to smallest (click opens them). Data from `scripts/almacenamiento.sh` (`discos`, `limpieza`, `paquetes`, `carpetas`: each in its own process, because `du` is slow).
  - **Connections:**
    - **Wi-Fi:** turn on or off, scan, connect, disconnect and forget networks. It tells three kinds apart by `nmcli`'s SECURITY field: **open** (empty or `OWE`: they connect without asking), **WPA/WPA3 personal** (password) and **802.1X enterprise** like eduroam (a form with user, password and method: PEAP/MSCHAPv2 by default or TTLS/PAP; under «Más opciones», anonymous identity and server domain, which turns on certificate validation against the system CAs and protects against fake «eduroam» networks). The 802.1X profile is created with `nmcli connection add … wpa-eap` and deleted if it does not connect. If a saved network asks for credentials, its form opens. A failed attempt leaves the card without a network (NetworkManager drops it while trying), so afterwards `nmcli device connect <card>` goes back to the best saved network. **DNS** (27 Sep) of the current connection, Wi-Fi or wired: automatic (the router's), Cloudflare (1.1.1.1), Google (8.8.8.8), Quad9 (9.9.9.9) or custom (IPv4 and IPv6 separated by spaces, validated); it shows the ones actually in use. Saved in the connection with `nmcli connection modify` (`ipv4/ipv6.dns` + `ignore-auto-dns`; IPv4 only if the connection does not support IPv6) and applied without disconnecting (`nmcli device reapply`); «Aplicar a todas las redes guardadas» sets it on every saved Wi-Fi and wired network. Logic in `NetworkService` (`dnsLoad`, `setDns`, `dnsParse`).
    - **Bluetooth:** turn on or off, scan, pair, connect and forget.
    - **Printers** (27 Sep, CUPS): if missing, «Instalar» installs `cups cups-filters ghostscript avahi nss-mdns` (without Ghostscript nothing prints: «gstoraster filter failed»; if it is missing, a warning with a button to install it) and enables the services (or «Activar» if they are only stopped). Printers with state (idle, printing, paused), default (`lpoptions -d`, per user), test page, resume when paused and remove with confirmation; the queue with each job's state (queued, printing, stopped, held; the reason in red if it failed), retry and cancel; printer error messages in red; and adding: search the network with avahi (`avahi-browse` of `_ipp._tcp`/`_ipps._tcp`, without root; added as `dnssd://<name>._ipp._tcp.local/`, which CUPS resolves even if the IP changes, and if `lpadmin` cannot use it (it has to talk to the printer and, without `nss-mdns` in `/etc/nsswitch.conf`, «.local» does not resolve), by its IP and path (`ipp://IP:631/<rp>`, from the announcement); if avahi is not running, it says so with a button to start it), USB (`lpinfo`, when CUPS allows it: as a user it usually answers «Forbidden», which is why the network does not go that way) or by address (IP → `ipp://IP/ipp/print`), driverless (`lpadmin -m everywhere`; if that does not work, it points to the vendor driver). If there was no default printer, the new one becomes the default. Refreshed every 5 s. Data from `scripts/impresoras.sh`.
  - **Personalization:**
    - **Wallpaper:** dot grid (with its tone) or an image from `~/Pictures/Wallpapers` («Importar» copies it there; each thumbnail's trash button, on hover, sends it to the system trash with `gio trash` and, if it was the current one, the dot grid comes back). **Wallhaven** (27 Sep): searches the public API v1 (`XMLHttpRequest`, SFW only, no key) as you type; ordering by top (last year), latest, random (pages keep the same seed) or relevance; categories; «Para mi pantalla» (for my screen) requires at least the physical resolution of the largest screen; thumbnails show resolution and size on hover, and «Cargar más» (load more) fetches 3 pages at once (72; the API gives 24 per page without a key). It searches 0.25 s after you stop typing and aborts the previous request. Click downloads it to `~/Pictures/Wallpapers/wallhaven-<id>.<ext>` (unless it is already there) and sets it. If Wallhaven rate-limits (429), it says so.
    - **Themes** (27 Sep): a theme recolors **the whole desktop**: the shell (live), Alacritty, walker, GTK apps (when restarted; plus the light/dark `color-scheme`) and Hyprland's borders. The installed ones (Nothing is bundled, `quickshell/temas/nothing.json`) with a preview (background, card, text, accent and terminal colors), apply and delete. **base16 catalog** from [tinted-theming](https://github.com/tinted-theming/schemes) (~350 schemes: Catppuccin, Gruvbox, Nord, Tokyo Night…; downloaded once to `~/.cache/quickshell/base16`, 󰑐 refreshes it) with search and a dark/light filter: choosing one lets you pick the **accent** among its colors and install, or install and apply. The 16 base16 colors are mapped to our layers (backgrounds and greys mixing background and text, the accent for what is active, red base08 for what is critical, the terminal in standard base16 order). Installed themes live in `~/.local/share/quickshell/temas/`. Below, the shapes: gaps, window rounding and screen corners (gaps and rounding also go to Hyprland). Everything is applied by `scripts/tema.sh` (see the shell's `CLAUDE.md`); `install.sh` (module `aspecto`) generates it with the current theme (or Nothing) when the generated files are missing.
    - **QuickShell → Lock screen:** a one-sentence summary of what happens and when (with a warning if the times contradict each other), minutes until lock, screens off and suspend; «Probar» (try: 15 s, unlocks by itself) and «Bloquear» (lock); face recognition (Howdy: on or off, enroll my face or install). **QuickShell → Bar:** the three zones (left, center, right) with the modules in order: click to show or hide, ‹ › to move them (or drag them on the bar itself); floating or attached style and clock. **QuickShell → Menu** (27 Sep): the system menu (SUPER+SPACE) as a tree: every section and entry with its switch (hiding a section hides what is inside, also in search), move the main menu sections up/down (the menu's height follows the number of sections), and **custom entries** (icon, name, command and section) that the menu runs. Saved in `settings.json` (`menuHidden`, `menuOrder`, `menuCustom`); `~/.local/bin/menu` reads it with `jq` when it opens (`--entradas-todas` prints the unfiltered table).
    - **Fonts** (27 Sep): installed families, each written in its own font with an editable sample text, with origin (repos, AUR, yours in `~`, system), package, files and size, and search; «Hacer predeterminada» (make default) sets it system-wide: if proportional, as the text font (`sans-serif` in fontconfig, `~/.config/fontconfig/conf.d/51-predeterminada-sans-serif.conf`, and GTK's `font-name`); if monospaced, as `monospace` (and `monospace-font-name`); the two current ones show at the top (`fc-match`). Each row in three lines (name and buttons; tags and info; sample) so it does not overflow; remove (with confirmation) uninstalls the package in the terminal or, if it is yours, deletes only its files in `~`. «Instalar desde archivo» (`.ttf/.otf/.woff/.zip` with zenity → `~/.local/share/fonts` + `fc-cache`). «Instalar más» searches as you type, only font packages (`ttf-*`, `otf-*`, `noto-fonts*`, `*-fonts`…) in the repos and the AUR. Data from `scripts/fuentes.sh`.
    - **Hyprland** (27 Sep): at the top, the **status**: `hyprctl configerrors` errors in red and a reload button (forces `hyprctl reload` and checks again). Then `hyprland.lua` and the modules it loads with `require()` (and `pcall(require, …)`, like the theme's `conf/tema.lua`) in load order, nested ones too (`conf/programs.lua`, which loads `conf/keybinds.lua`, is shown indented below it), with the first line of its comment and an **«Editar en nvim»** button that opens it in the menu's floating terminal (with `~/.config/hypr` as working directory). The list is read when the page opens, so a new `require` shows up by itself. `conf/shell-settings.lua` is generated by the shell: its button says «Ver en nvim» (view). At the bottom, the whole folder opens in nvim.
  - **Apps** (27 Sep):
    - **Installed:** the launcher's apps (visible `.desktop` files; the user's overrides the system's; localized name if present) with their origin (repos, AUR, Flatpak, web app, TUI or by hand: the package comes from `pacman -Qo`), icon, size, search, sorting by name or size and a filter by origin; or **all packages** (dependencies too, with an explicit / dependencies filter). Uninstall asks for confirmation in the row: pacman (`-Rns`) and Flatpak in the floating terminal, web apps and TUIs with `webapp/tui quitar`. From Storage («Gestionar») it arrives with the app searched and highlighted.
    - **Install:** searches the repos, the AUR (by popularity) and Flathub at once **as you type** (after 0.4 s without typing and with 2 or more letters; aborts the previous search), with a filter by origin; install runs in the floating terminal and, when done, the search runs again to mark what is installed. Forms to create a web app (name, site, optional icon) or a TUI (name, command, floating or tiled, icon) with `webapp crear` / `tui crear`.
    - Data from `scripts/aplicaciones.sh` (`instaladas`, `paquetes`, `buscar-repos|aur|flatpak`).
  - **Updates:** pending ones from the repos, the AUR and Flatpak **with the package list** (current version → new; the kernel and Hyprland marked as needing a reboot; more than 12 collapse), **snapshot without updating** (`scripts/snapshot.sh`: like arch-update's, replaces the previous one; with an optional description; re-signs the boot files if needed), and every way of updating in the floating terminal: the whole system or repos only (`scripts/actualizar.sh` → `arch-update --menu`, which waits for a «Cerrar» button), AUR only, Flatpak and firmware; plus restarting the shell and walker.
- **One source for every value:**
  - **Gaps, rounding, keyboard, mouse and touchpad:** in `settings.json`. The shell generates `conf/shell-settings.lua` (Hyprland reloads it by itself) and those keys are no longer in `look-and-feel.lua` or `input.lua`. The idle times generate `hypridle.conf`. `settings.json` and both generated files are not in git.
  - **Network:** all the logic is in `NetworkService.qml`, shared by the bar, the panel and Settings.
- Development details and known pitfalls: `~/.config/quickshell/CLAUDE.md`.

## Components

| File | What it does |
|---|---|
| `shell.qml` | Entry point |
| `Theme.qml` | Colors, fonts, margins and radii |
| `Config.qml`, `settings.json` | Persistent settings (not in git); generates `~/.config/hypr/conf/shell-settings.lua` (gaps, rounding and every input option) and `~/.config/hypr/hypridle.conf` |
| `ShellState.qml` | Shared state (power menu, focused screen) |
| `Bar.qml` | Bar (floating or attached to the top, per `Theme.barStyle`); draws each zone in `Config.barLayout` order |
| `Workspaces.qml` | Workspaces 1–5 always visible, the same on every monitor |
| `Media.qml` | MPRIS player (click on the title: panel) |
| `MediaPanel.qml` | Player panel: cover, progress, controls and sources |
| `MediaService.qml` | MPRIS players and which one is controlled |
| `Clock.qml` | Date and time (time in Doto, dot matrix) |
| `Tray.qml` | Collapsible system tray |
| `NetworkService.qml` | Shared network logic (nmcli) |
| `Network.qml`, `NetworkPanel.qml`, `WifiList.qml` | Network state, Wi-Fi panel and network list |
| `SystemMonitor.qml` | System monitor (click: btop; on hover, CPU, RAM and both GPUs) |
| `Mic.qml` | Default microphone: click mutes or unmutes (muted, in red), right click opens the sound panel, wheel: input volume. The bar's «Micrófono» module (`barMic`) |
| `Volume.qml`, `Battery.qml` | Volume (PipeWire; click: `SoundPanel.qml`, right click: mute) and battery (UPower; on hover, time, power draw and dGPU) |
| `SoundVolumeRow.qml`, `SoundDeviceList.qml` | Volume row and device list, shared by the sound panel and Settings → Sound |
| `PowerButton.qml`, `PowerMenu.qml` | Power menu |
| `LockScreen.qml`, `LockSurface.qml` | Lock screen: session lock, PAM and IPC; per-monitor content |
| `Notifications.qml` | Notification server with popups |
| `Osd.qml` | Volume, microphone and brightness indicator |
| `Wallpaper.qml` | Wallpaper: dot grid or a static image (Settings → Personalization → Wallpaper); dots if the image does not exist |
| `ScreenCorners.qml` | Rounded screen corners |
| `SettingsWindow.qml` + `Settings*.qml` | Settings window: section tree in `Config.settingsTree`, `Settings*.qml` pages (`SettingsSoon.qml` for missing ones) and shared parts (`SettingsPage`, `SettingsGroup`, `SettingsRow`, `Button`, `ChoiceChips`, `Toggle`, `SliderField`) |
| `MonitorForm.qml` | One monitor's form (Settings → Displays) |
| `WifiField.qml`, `ChoiceChips.qml`, `Stepper.qml` | Text field, option chips and ‹ value › selector |
| `NotificationButton.qml` | The bar's bell: history and Do Not Disturb |
| `Slider.qml`, `SliderField.qml`, `Toggle.qml` | Shared controls |
| `scripts/brillo.sh` | Brightness per monitor: backlight on the internal panel, DDC/CI on external ones |

IPC (`qs ipc show` for the full list):

```
qs ipc call settings open <section>   # Settings (home, display, wifi, bar, updates…: keys of Config.settingsTree); toggle opens/closes
qs ipc call powermenu toggle          # power menu
qs ipc call lock lock                 # lock (better with `bloquear`, which has a fallback)
qs ipc call lock prueba               # lock for 15 s and unlock by itself (to see how it looks)
qs ipc call osd brightness            # brightness OSD (after changing it)
qs ipc call notifications dnd         # toggles Do Not Disturb and returns the state
qs ipc call wallpaper set <path>      # image wallpaper (dots: dot grid)
qs ipc call sharepicker cancel        # closes the screen-share picker (compartir-pantalla opens it)
```

Dependencies: `quickshell`, `hyprland`, `networkmanager` (nmcli), `brightnessctl`, `ddcutil`
(external monitor brightness, with the `i2c-dev` module and the `i2c` group),
`power-profiles-daemon`, `asusctl` (charge limit), `zenity` (importing wallpapers), `hyprlock`
(lock screen fallback), `ttf-jetbrains-mono-nerd` and the [Doto](https://fonts.google.com/specimen/Doto) font.

## Language

- **What it does:** the shell's texts are in English in the code, wrapped in `I18n.tr("…")`
  (`I18n.qml`), and `i18n/es.js` has the Spanish for each one. Settings → System → Language
  (`SettingsLanguage.qml`) picks **Automatic** (Spanish if `$LANG` is Spanish, English otherwise),
  English or Español; it is saved as `language` in `settings.json` and applied at once, without
  restarting (every binding that calls `I18n.tr` depends on the language).
- **Dates:** with `I18n.locale` (`es_ES` or `en_GB`) and, for custom formats, a translatable
  format string (`I18n.tr("MMMM d, yyyy")`).
- **Values and plurals:** `I18n.tr("%1 free").arg(size)`; `I18n.trn(n, "%1 app", "%1 apps")`.
- **Same English, different Spanish:** a context, `I18n.tr("All", "apps")` → key `All|apps`
  («Todas»), `I18n.tr("All", "packages")` → «Todos».
- **Data structures in `Config.qml`** (Settings tree, bar modules) keep English labels and are
  translated where they are shown: `I18n` reads `Config`, so `Config` cannot call `I18n`.
- **New text:** write it in English inside `I18n.tr` and add its Spanish to `i18n/es.js` (one
  line per entry, sorted). A missing entry just shows the English. **New language:**
  `i18n/<code>.js` with the same keys, import it in `I18n.qml` and add it to `languages`.
- **Scripts (bash):** the same dictionary and setting through `i18n/i18n.sh`: `source` it and
  `t "English text"` (values with `%s`: `t "WebApp created: %s" "$name"`). It is used by the walker
  menu (`~/.local/bin/menu`, which also translates the elephant menus through `menu --entradas`),
  `menu-atajos`, `captura`, `grabar`, `webapp`, `tui`, `paquetes`, `walker-launch` (search
  placeholder), `scripts/actualizar.sh`, `scripts/snapshot.sh` and `arch-update` (as root: it reads
  the session user's settings through `I18N_HOME`). Lua (`elephant/menus/fondos.lua`) calls it
  through `bash`. In bash, a key ending in `\n` only works with values (printf); otherwise use
  `echo "$(t …)"`.
- **Keybinds:** descriptions and `-- ## …` headings in `conf/keybinds.lua` are in English and are
  translated where shown (Settings → Keybinds, `menu-atajos`); a trailing number or range
  («Go to workspace 3») is kept and the rest translated.
- **Installer:** `install.sh` and `instalar/` use `t` too (sourced from the repo, so it works before
  the links exist); the language follows `$LANG`, or `./install.sh --lang en|es` (`I18N_LANG`).
  Module descriptions are one-line texts wrapped with `fold` when shown.
- **Still only in one language:** walker's «No results» (static in `config.toml`, English) and the
  texts of `hyprlock.conf` (fallback lock). The Settings
  window title stays «Ajustes» because `conf/rules.lua` matches it.

## Brightness (`scripts/brillo.sh`)

- **Problem 1:** there are two backlights, and `brightnessctl` picked `nvidia_0` by default, a fake one that does nothing. The real one is `amdgpu_bl1`. The slider and the keys did not work.
- **Problem 2:** brightness only controlled the internal panel.
- **Solution:** one script, used by the keys, the OSD and Settings.
  - `brillo.sh get [MONITOR]` and `brillo.sh set VALUE [MONITOR]`. Without a monitor, the focused one.
  - **Internal panel:** the backlight of the GPU the eDP is connected to. It adapts by itself if the GPU mode changes.
  - **External monitors:** DDC/CI with `ddcutil` (VCP 0x10), with the i2c bus and the maximum cached. A change takes about 0.15 s.
  - **Settings slider:** sends while you drag, one process at a time. It used to launch many `ddcutil` processes at once and **slowed the whole system down**.

## Where it comes from: illogical-impulse (ii), installed and removed

ii (end-4's dots) was installed and later fully removed, to use an own shell without duplicated files.

- **Files:** the 1042 files of its install list, its cloned repo (2.8 GB in `~/.cache/dots-hyprland`) and `~/.config/illogical-impulse` were removed. The modular `conf/` config came back.
- **Packages** (by script): the 15 `illogical-impulse-*` metapackages and about 100 orphans were removed.
  - **Protected before removing:** 50 packages that were already installed and that ii had re-marked as its dependencies, among them Hyprland, NetworkManager, pipewire-pulse, wireplumber, kitty and the portals. Without that protection they would have been deleted.
  - **Kept for the shell:** hyprlock, hypridle, brightnessctl and ttf-jetbrains-mono-nerd.
  - **Installed instead:** the official `quickshell` (0.3.1) and `adw-gtk-theme`.
  - **System settings undone:** the i2c and input groups, the ydotool service and the i2c-dev module. The module and the i2c group were added back later, for the external monitor's brightness ([SYSTEM.md](SYSTEM.md#external-monitor-brightness-ddcci)).
- The ii and previous config backups (`~/backup-*`) were deleted.

## Pending

- Lock screen with face unlock (26 Sep: tested with `qs ipc call lock prueba`, unlocks in ~1.3 s):
  check that opening the lid after suspend looks for the face without pressing anything, that
  covering the camera shows the «face not recognized» message and the password works, and that
  after an idle lock a key retries the face. After a reboot it asks for the password (verified, on
  purpose: keyring).
- Try with real clicks: connecting to new networks (open and eduroam with the 802.1X form) and
  pairing Bluetooth devices.
- Try a real resolution or position change in Settings → Displays and confirm with «Keep».
- Language (28 Sep): check every page in English and in Spanish after the move to `I18n.tr` (tested
  here only with qmllint and an offscreen test of `I18n`, not with Quickshell running).
