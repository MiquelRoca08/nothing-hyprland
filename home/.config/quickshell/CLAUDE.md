# CLAUDE.md

Custom Quickshell shell for Hyprland, monochrome in the Nothing OS style. It loads from
`~/.config/quickshell/shell.qml` with `qs` (started by Hyprland in
`~/.config/hypr/conf/autostart.lua`). It lives in the dotfiles repo
(https://github.com/MiquelRoca08/nothing-hyprland, in `home/.config/quickshell/`); `~/.config/quickshell`
is a symlink to that folder. Commit and push from `~/dotfiles`.

Reply in the user's language. Code comments, `docs/` and commit messages are in
English (public repo). UI texts are written in English inside `I18n.tr("…")`, and each new one
gets its Spanish in `i18n/es.js` (see «Language» in `docs/QUICKSHELL.md`).

## Environment

- **Quickshell 0.3.1** (official Arch package). Do not use APIs from `-git` versions.
- **Hyprland 0.56 with a Lua config** (`~/.config/hypr/hyprland.lua` + modules in `conf/`).
  Dispatchers are written in Lua; the classic syntax is an error:
  - QML: `Hyprland.dispatch("hl.dsp.focus({ workspace = 3 })")`
  - Shell: `hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`
- Usually several monitors with different scales (e.g. a HiDPI laptop panel at 2 and an external one
  at 1): check them with `hyprctl monitors` and test anything size-dependent at both scales.

## Structure

- `shell.qml`: entry point. `Variants` over `Quickshell.screens` for what goes on each monitor
  (Wallpaper, Bar, ScreenCorners); the rest is single (Notifications, Osd, PowerMenu).
- `Theme.qml` (singleton): **all** colors, fonts and measurements. Do not put loose colors in
  other files. Palette: layers of black and grey (`bg` → `bgAlt` → `surface` cards → `control`
  controls → `controlHi` hover, `border`), whites for text (`fg`, `fgSoft` secondary, `dim`
  descriptions) and Nothing red for what is **active** (`sel`: selected, on, main button; `selHi`
  hover; `selSoft` tinted background; `selText` text on top) and what is critical (`red`).
  `accent` (white) is for the bar: workspaces, OSD and power menu. Measurements and the background
  tone come from `Config.options` (do not hard-code them in Theme).
- **Desktop themes:** `Theme`'s colors come from the active theme,
  `~/.local/share/quickshell/theme/current.json` (reread live; without it, Nothing's). A theme is a
  JSON (`themes/nothing.json` as an example: `colors` with the tokens and `terminal` with the 16
  terminal colors). `scripts/theme.sh apply <json>` applies it to the whole desktop: besides the
  shell, it generates Alacritty (`~/.local/share/quickshell/theme/alacritty.toml`, imported), walker
  (`walker/themes/nothing/theme.css`, imported after `colors.css`), GTK (`~/.config/gtk-{3,4}.0/theme.css`,
  the only thing `gtk.css` imports) and Hyprland's borders (`hypr/conf/theme.lua`, with
  `pcall(require)`); the ones inside the repo are in `.gitignore`. **A new color:** add it to the
  JSONs, to `Theme.qml` with its Nothing value and, if another program uses it, to `theme.sh`.
  Settings → Themes converts base16 schemes (`theme.sh catalog`) to these tokens (`fromBase16`:
  layers mixing base00 with base05; accent chosen among base08…base0F).
- **Settings design (keep it consistent):** each page is a `SettingsPage` (header with the section
  icon in red, `title` = the sidebar name and a one-line `subtitle`) with `SettingsGroup` (cards)
  and `SettingsRow` (text on the left, control on the right). Controls: `Button` (`kind: "primary"`
  red for the main action of a block, `"secondary"` grey for the rest, `"ghost"` for minor actions
  like «Reset»; `busy` while working), `ChoiceChips` (pick one option; the chosen one in red),
  `Toggle`, `SliderField`, `WifiField` (text; `search: true` for search boxes: magnifier and an X to
  clear), `Tag` (origin or state tag), `IconButton` (icon-only button: delete, close, remove;
  `danger` turns it red on hover; `overlay` to sit on an image; every trash button is an
  `IconButton`, and if confirmation is needed, «Cancel» and a primary `Button` with the action's
  text appear in the row) and `UsageBar` (usage: white, red from `critical`). Commands in the
  floating terminal: the `Terminal` singleton (`open`, `run`). Scrolling: every `Flickable` has
  `FastWheel { flick: … }` inside (Qt's is very slow on Linux with wheel and touchpad) and, if it
  can be long, `ScrollBar { parent: theFlickable; flick: … }` (with `parent` the Flickable itself, so
  it does not move with the content). Do not build buttons or chips with `Rectangle` + `MouseArea`:
  use those. **Bar:** a clickable module puts `BarHover {}` inside (grey background on hover, like
  `IconButton`); what is active uses `Theme.sel`, and popups `Theme.cardRadius`. What is still to do is `soon` in the tree (`SettingsSoon.qml` shows up with the
  «Coming soon» label).
- `Config.qml` (singleton) + `settings.json`: persistent settings edited by the Settings window
  (appearance, bar modules, keyboard/mouse/touchpad, lock, Do Not Disturb).
  `Config.reset(keys)` resets those keys to `Config.defaults`.
- `NetworkService.qml` (singleton): all the network logic (nmcli). Used by the bar (`Network.qml`),
  the panel (`NetworkPanel.qml`) and Settings; the network list is `WifiList.qml`, shared. Each
  network has a `type`: `open`, `psk` or `eap` (802.1X, eduroam: `connectEnterprise`). The current
  connection's DNS is here too (`dnsMode`, `dnsPresets`, `setDns(servers|null, all)`). The form
  text fields are `WifiField.qml`.
- Settings sections: the `Config.settingsTree` tree (categories with `children` and pages with
  `file`, or `soon` if not done yet); `Config.settingsFlat` flattens it with `depth` and `parents`,
  and `Config.settingsEntry(key)` gives a key's page (the first of a category; old keys go through
  `settingsAliases`). **New section:** add it to the tree. `SettingsWindow.qml` (FloatingWindow):
  sidebar with collapsible categories (the current page's one is open; clicking a category
  collapses it or goes to its first page) and the page in a `Loader`. It always opens on **Home**
  (`ShellState.openSettings(key)` or `qs ipc call settings open <key>` for another one) with
  SUPER+I or the bar's 󰒓 button.
- Pages: Home (`SettingsHome`: summary cards that lead to their section, tasks in
  `~/.local/share/quickshell/tasks.json` and machine info); System: `SettingsDisplay`,
  `SettingsSound`, `SettingsInput`, `SettingsNotifications`, `SettingsPower` (Battery),
  `SettingsKeybinds` (reads and rewrites `conf/keybinds.lua`; `-- ## …` sections; captures in the
  `capture` submap); `SettingsStorage` (data from `scripts/storage.sh`); Apps:
  `SettingsAppsInstalled` and `SettingsAppsInstall` (data from `scripts/apps.sh`; icons with
  `AppIcon`); Connections: `SettingsWifi`, `SettingsBluetooth`, `SettingsPrinters` (CUPS; data from
  `scripts/printers.sh`); Personalization: `SettingsWallpaper`, `SettingsThemes` (desktop themes
  and shapes), `SettingsFonts` (data from `scripts/fonts.sh`), QuickShell → `SettingsMenu`
  (walker menu: `menuHidden`, `menuOrder`, `menuCustom`, read by `~/.local/bin/menu`),
  `SettingsIdle` (Lock screen) and `SettingsBar`, `SettingsHyprland` (hyprland.lua and its
  `require`s, with a button to open them in nvim); `SettingsUpdates` (uses the `UpdateService`
  singleton, which Home reads too). The rest, «Coming soon».
- `MediaService.qml` (singleton): MPRIS players and which one is controlled (the one chosen in the
  panel, otherwise the one playing). Used by `Media.qml` (bar) and `MediaPanel.qml` (panel with
  cover art, progress, controls and the source list).
- Sound: `Volume.qml` (bar; click: `SoundPanel.qml`, right click: mute) and Settings →
  `SettingsSound`; both use `SoundVolumeRow` and `SoundDeviceList`. The apps playing are the nodes
  with `isStream && isSink` (recording ones have `isSink = false`) with a `PwLinkState.Active` link in
  `Pipewire.linkGroups` (Firefox leaves another stream open and stopped). The links must be tracked
  with their own `PwObjectTracker` (otherwise their state stays `Unlinked`; and in the same tracker
  as the streams it gives a «binding loop»). A node's `properties` arrive late: do not filter by
  them.
- `ShellState.qml` (singleton): shared state (`powerMenuOpen`, `focusedScreen`, Settings page,
  in-memory notification history and unread counter).
- `SharePicker.qml`: the portal's (xdph) screen-share picker, with `SharePreview` (card with a
  `ScreencopyView`) and `ShareButton`. Opened by `~/.local/bin/share-picker` over IPC; it
  answers through a FIFO (format in the file's comment). Try it: `qs ipc call sharepicker open
  <fifo> '' false` (with a `cat <fifo>` waiting) and close with `qs ipc call sharepicker cancel`.
- IPC: `settings`, `powermenu`, `lock` and `sharepicker` in their component, `osd` in `Osd.qml`;
  `notifications dnd` and `wallpaper set <path>|dots` in `shell.qml` (used by the system menu,
  `~/.local/bin/menu`).
- `Battery.qml`: on hover, a `PopupWindow` (no focus grab) with time left, power draw and the
  NVIDIA dGPU state (sysfs `power/runtime_status`; do not use `nvidia-smi`, it wakes it up).
- `SystemMonitor.qml`: click opens btop (`alacritty --class TUI.float`); on hover, CPU, RAM and
  AMD/NVIDIA GPU. `nvidia-smi` is only called if `runtime_status` is already `active`.
- Lock: `LockScreen.qml` (`WlSessionLock` + `PamContext` with the `quickshell-lock` service, IPC
  `lock`) and `LockSurface.qml` (what shows on each monitor). Always lock with
  `~/.local/bin/lock-screen` (falls back to hyprlock if the shell does not answer). The
  `$XDG_RUNTIME_DIR/qs-locked` marker makes the shell lock again when it restarts. PAM starts on
  lock and on any key (for password-less modules, like face recognition); the password is handed
  over when PAM asks for it. With Howdy it uses the `quickshell-lock-face` service, only if the
  GNOME keyring is already unlocked (otherwise the password is the only thing that unlocks it).
  `PamContext.abort()` is synchronous and does not emit `completed`; after `error`,
  `completed(Error)` does arrive.
- Bar order: `barOrder` in `settings.json` (`{ left, center, right }`, lists of keys). The module
  list with each name and the option that hides it is `Config.barModules`; `Config.barLayout` is
  the sanitized order (no duplicates or unknown keys; anything missing goes at the end of the
  right) and `Config.placeBarItem(key, zone, position)` changes it. `Bar.qml` builds each zone with
  a `Repeater` and a `DelegateChooser` (role `k`); each module has a `BarDrag` (a `DragHandler`
  that only activates past the threshold, so the module's clicks work as before) and `Bar.qml`
  paints the copy (`ShaderEffectSource`) and the line of the closest slot (`dropFor`). Settings →
  Personalization → QuickShell → Bar only has the show/hide switches. **New module:** add it to
  `barModules`, to a `DelegateChoice` in `Bar.qml` and, if it has a switch, its `barXxx` to
  `Config`, and give it `BarDrag { key: "…"; panel: bar }`; it shows up by itself at the end of
  the right.
- `BarText.qml`: text with the common style; use it instead of `Text`.
- `I18n.qml` (singleton): interface language. `I18n.tr("English text")` (optional context as a
  second argument), `I18n.trn(n, one, many)`, `I18n.locale` for dates. Spanish in `i18n/es.js`.
  Labels in `Config.qml` stay in English and are translated where shown (`I18n` reads `Config`).
- One component per file; each file starts with a comment saying what it does.

## Files the shell generates

`settings.json` is the only source of these values; `Config.qml` generates (only if something
changes):

- `~/.config/hypr/conf/shell-settings.lua`: `gaps_in`, `gaps_out`, `rounding` and **all** the
  general `input` options (keyboard, mouse and touchpad; see `Config.writeHyprland`). Hyprland
  reloads it by itself. It loads after `conf/input.lua`; do not put those keys in `input.lua` or in
  `look-and-feel.lua`.
- `~/.config/hypr/hypridle.conf`: lock, screen and suspend timeouts. hypridle only reads its config
  on startup and `FileView.setText` is asynchronous: it is restarted in `onSaved`, not right after
  `setText` (otherwise it starts with the old version).

Also, `SettingsDisplay` rewrites `~/.config/hypr/conf/monitors.lua` on «Apply» (only the
`hl.monitor` of connected monitors, with a rollback after 15 s done by a separate process); that
file can be edited by hand: the form (`MonitorForm.qml`) reads Hyprland's real values. Reusable
form pieces: `ChoiceChips.qml` (chips), `Stepper.qml` (‹ value ›) and `WifiField.qml` (text field).

Do not edit them by hand. `hl.config(...)` **cannot** be applied with `Hyprland.dispatch`
(Hyprland only accepts `hl.dsp.*` dispatchers).

## Known pitfalls

- **New files, singletons and live reload:** Quickshell reloads by itself on save, but a component
  in a new `.qml` file sometimes does not register, and changes to singletons (`Config.qml`) may
  not apply. If something does not show up, restart:
  `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs")'`.
- **Property names:** a property starting with `on` + an uppercase letter (`onAccent`) is taken as
  a signal handler and breaks loading. Do not redefine Item properties such as `states`, `state`,
  `enabled` (use another name, e.g. `active`), `scale`, `transform`, `rotation` or `opacity`
  («Cannot override FINAL property» or, worse, it scales the whole component).
- **`Image` and its implicit size:** in `Image`, `implicitWidth`/`implicitHeight` are read-only
  (they come from the image): assigning them breaks the component's loading («Type X unavailable»
  in whoever uses it). For a fixed-size icon, an `Item` with the `Image` inside (`AppIcon.qml`).
- **Dropping focus with a click outside:** a `Flickable` takes the click before its ancestors'
  handlers, so the `TapHandler` that drops it also has to be inside the page's `Flickable`
  (`SettingsWindow`), not only in the outer layout.
- **Hover with buttons inside:** a `MouseArea` with `hoverEnabled` (the one in `IconButton`) takes
  the hover away from its parent's `HoverHandler`: whatever depends on it flickers when passing
  over the button. Combine both (`IconButton.hovered`), as in the `SettingsBar` chips.
- **Seeing a piece without Quickshell:** with PySide6, QML can be drawn without a screen
  (`QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software`, `QQuickView` + `grabWindow`) with a test
  `Theme` and the components that do not depend on Quickshell (`BarText`, `Button`, `Tag`,
  `ChoiceChips`, `WifiField`…); and clicks and keys can be simulated with `QtTest`.
- **Validate before testing:** `qmllint -I . File.qml` (Qt 6; it comes with PySide6) catches load
  errors like the one above or non-existent properties. It does not know Quickshell's modules:
  ignore its warnings about `Process`, `ShellState`, `Terminal`… not found.
- **Handlers with loops:** `onTriggered: for (…) …` does not compile; it needs braces:
  `onTriggered: { for (…) … }`.
- **Brightness:** always use `scripts/brightness.sh get|set` (keys, OSD and Settings), never bare
  `brightnessctl`: there are two backlights and the default one (`nvidia_0`) is fake; the script
  uses the one of the GPU the internal panel is connected to (now `amdgpu_bl1`). sysfs emits no
  events, so the OSD is triggered by the keybind with `qs ipc call osd brightness`. Volume is
  detected by itself (PipeWire).
- **Notification `expireTimeout`:** some apps send it in ms and others in seconds;
  `Notifications.qml` normalizes it.
- **Bluetooth and rfkill:** if the adapter is blocked by rfkill (`BluetoothAdapterState.Blocked`),
  `adapter.enabled = true` fails («blocked by rfkill»). `rfkill unblock bluetooth` is needed first
  (the user has permission on `/dev/rfkill`); on turning it off, `SettingsBluetooth` blocks it again.
- **Bindings that break:** assigning a bound property by hand (`text = …`) breaks the binding
  forever. In editable fields (e.g. `SliderField`), always assign by hand and refresh from
  `onValueChanged` instead of binding.
- **`modelData` is a copy:** with a JS array as a `Repeater`'s `model`, each row's `modelData` is a
  new object, not the one in the original array: `t === modelData` never finds the original (that
  is how «mark as done» and «delete» failed in Tasks). Identify by a field (the `SettingsHome`
  tasks use `created`). And with `JsonAdapter`, reading a property right after assigning it in the
  same function can return the previous value.
- **Nested layouts:** a `RowLayout`/`ColumnLayout` inside another one stretches by default
  (`Layout.fillWidth: true`), and a layout can only grow if some child can. `SettingsRow` relies on
  both to align the control to the right.
- **`parent` in components with `default property alias`:** the children end up inside the slot
  (`slot`), not in the component; use an `id` instead of `parent.property`.
- **Hyprland requires:** if `hyprland.lua` `require`s a module that does not exist, loading of the
  whole config stops. Create the file before adding the `require`.
- **MPRIS position:** `position` does not notify by itself; `player.positionChanged()` has to be
  called periodically (`MediaPanel` does it while open).
- **nmcli:** use `-t --escape no` and put the SSID as the last field (it can contain `:`). A failed
  `nmcli connection up` leaves the card **without network** (it drops the connection it had): do not
  test connections with made-up networks while connected, and after a failure run
  `nmcli device connect <card>` (`NetworkService` already does it).
- **Canvas** (background, corners): it paints once; if it depends on the theme, redraw with a
  `deps` property listing the Theme values used (`onDepsChanged: requestPaint()`).
- **`qs ipc call` exits with 0 even when it fails** («Target not found.», shell not started): to
  know whether it worked, check that there is no output (in `void` functions) or the returned value.
- **No BigInt:** QML's JS engine has no `BigInt`; for 64-bit numbers that fit in 53 bits (Hyprland
  window addresses) use `Number(...)`.
- **Live reload and `sed -i`:** editing with `sed -i` (which replaces the file) sometimes does not
  trigger the reload; if a change does not show, restart the shell.
- **One change = one assignment in `Config.options`:** each assignment saves `settings.json`, and
  the file is reread on change (`watchChanges`). If one change is split into several assignments in
  a row, intermediate states slip through (it happened with the bar order in three keys): build an
  object and assign it whole.
- **Reordering from the row itself:** if on release you change the `Repeater`'s model, the row
  (and its `MouseArea`) is destroyed right then and whatever comes after in the handler does not
  run (the copy stayed painted). Clear the drag state **before** saving the new order.
- **`MouseArea` with `hoverEnabled`:** `onPositionChanged` also arrives without pressing; in a
  drag, check `pressed`.
- **Popups** (`PopupWindow` + `HyprlandFocusGrab`): with the tray, disable the grab while a menu is
  open (`menuOpen`), or the panel closes when using the menu.

## How to test changes

- Errors: `qs log | grep -iE 'error|warn'` (old errors stay in the log; check that the last line
  is `Configuration Loaded`).
- Screenshots: `grim -o <monitor> file.png` (and crop with `magick`). Popups, OSD and notifications
  show on the **focused** screen:
  `hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'`.
- Active layers: `hyprctl layers -j` (namespaces `qs-*`). `PopupWindow`s are not layers and do not
  show there.
- Lock screen: `qs ipc call lock test` locks for 15 s and unlocks by itself (does nothing if it
  was already locked). **Do not really lock to test** without the user in front: the password
  cannot be typed from here. And careful with `pkill -x qs` while locked: the shell locks again on
  startup (`qs-locked` marker), it does not unlock.
- Settings: `qs ipc call settings open <section>` and capture the window with
  `hyprctl clients -j` (title `Ajustes`) + `grim -g`.
- Panels with `HyprlandFocusGrab` opened with a test `Timer`: since there is one bar per monitor,
  two open and one's grab closes the other (sometimes both). For the screenshot, also set
  `active: false` on the grab and revert afterwards.
- Typing into walker or other windows: `wtype text`, `wtype -k Escape`.
- Real clicks, drags and wheel: `scripts/mouse.py click x y`, `scripts/mouse.py drag x1 y1 x2 y2
  ["command"]` and `scripts/mouse.py scroll x y n` (virtual mouse through uinput; global
  coordinates like `hyprctl cursorpos`, e.g. a monitor placed at 1440,-600 starts there; the optional command runs
  with the button still pressed, handy for screenshots). To locate an icon, capture the bar at real
  size with `grim` and crop with `magick`.
- Without the virtual mouse, to see a panel temporarily add
  `Timer { interval: 2000; running: true; onTriggered: root.open = true }` and **revert** it
  afterwards. With a fixed `open: true` it does not show: the popup is created before the bar is
  mapped. For a tooltip with `HoverHandler` + `LazyLoader { active: hover.hovered }`, however,
  setting `active: true` for a moment and saving is enough (with the shell already loaded, it shows).
