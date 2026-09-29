-- Keybinds — https://wiki.hypr.land/Configuring/Basics/Binds/
-- Every bind has a «description»: it is what the keybind list shows (SUPER+K, menu-atajos) and
-- Settings → Keybinds, which groups them by the «-- ## …» headings and can change the key of
-- single-line binds (rewriting their first argument here). Descriptions and headings are in
-- English and are shown in the interface language (~/.config/quickshell/i18n/es.js).

local programs    = require("conf.programs")
local terminal    = programs.terminal
local fileManager = programs.fileManager
local menu        = programs.menu

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

local function d(texto) return { description = texto } end

-- ## Apps and windows
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), d("Terminal"))
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), d("Terminal"))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close(), d("Close window"))
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), d("Log out"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(fileManager), d("Files"))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }), d("Floating / tiled window"))
-- hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), d("Toggle the split (horizontal / vertical)"))    -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), d("Fullscreen"))
-- Next window on the workspace, raised in case it is floating (like Omarchy)
hl.bind("ALT + TAB", function()
    hl.dispatch(hl.dsp.window.cycle_next())
    hl.dispatch(hl.dsp.window.bring_to_top())
end, d("Next window on the workspace"))

-- ## Menu, launcher and tools
-- Walker: launcher, system menu and helpers (~/.local/bin)
-- submap_universal: also works with a menu open («menu» submap), to close it
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("menu"), { submap_universal = true, description = "System menu (open / close)" })
hl.bind(mainMod .. " + ALT + SPACE", hl.dsp.exec_cmd(menu), d("Open apps"))
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("menu-atajos"), d("Keybind list"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("walker-launch -m clipboard"), d("Clipboard history"))
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("walker-launch -m symbols"), d("Emoji and symbols"))
hl.bind(mainMod .. " + CTRL + O", hl.dsp.exec_cmd("menu actions"), d("Actions (screenshot, record, Do Not Disturb, lock, screen)"))

-- ## Inside the menus
-- «menu» submap: only while a system menu is open (~/.local/bin/menu turns it on).
-- Backspace goes back like Escape; every other key reaches walker.
hl.define_submap("menu", function()
    hl.bind("BackSpace", hl.dsp.exec_cmd("menu-atras"), d("Go back (in the menus)"))
end)

-- ## Screenshots and recording
hl.bind("Print", hl.dsp.exec_cmd("menu screenshot"), d("Screenshot menu"))
hl.bind(mainMod .. " + CTRL + C", hl.dsp.exec_cmd("menu screenshot"), d("Screenshot menu"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("captura zona"), d("Capture a region"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("captura zona"), d("Capture a region"))   -- like Win+Shift+S
hl.bind("ALT + Print", hl.dsp.exec_cmd("menu record"), d("Record the screen (or stop)"))

-- ## Windows and workspaces
-- Focus with SUPER + arrows
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  d("Focus left"))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), d("Focus right"))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    d("Focus up"))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  d("Focus down"))

-- Go to a workspace with SUPER + [0-9]; move the window with SUPER + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}),        d("Go to workspace " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }), d("Move the window to workspace " .. i))
end

-- Escritorio especial (oculto)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"),            d("Show / hide the hidden workspace"))

-- Workspaces with windows: next / previous
hl.bind(mainMod .. " + TAB",         hl.dsp.focus({ workspace = "e+1" }), d("Next workspace"))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }), d("Previous workspace"))

-- Cycle workspaces with SUPER + wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), d("Next workspace"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), d("Previous workspace"))

-- Move and resize with SUPER + left / right click and drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Move the window (drag)" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize (drag)" })

-- ## Volume, brightness and media
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "Mute" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "Mute the microphone" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("~/.config/quickshell/scripts/brillo.sh set 5%+ && qs ipc call osd brightness"),                  { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("~/.config/quickshell/scripts/brillo.sh set 5%- && qs ipc call osd brightness"),                  { locked = true, repeating = true, description = "Brightness down" })

-- Playback (playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Next track" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play / pause" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Previous track" })

-- ## System
-- Power off, reboot, lock…: the walker menu's «System» submenu. The shell's power menu
-- (~/.config/quickshell/PowerMenu.qml) is still there, but without a bind (opens from the bar)
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("menu system"), d("Power menu (System)"))

-- Settings (~/.config/quickshell/SettingsWindow.qml)
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle"), d("Settings"))

-- «captura» submap: empty. Settings → Keybinds turns it on while a new combination is chosen,
-- so it reaches the window instead of running the bind it already has.
-- Escape goes back to normal (if something fails, Settings also goes back by itself after a few seconds).
hl.define_submap("captura", function()
    hl.bind("Escape", hl.dsp.submap("reset"), d("Cancel (while choosing a keybind in Settings)"))
end)
