-- Autostart — https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
    -- "Login" screen: the session starts with autologin (greetd) and locks at once
    -- with the shell's lock screen (~/.local/bin/lock-screen; if the shell does not load, hyprlock)
    hl.exec_cmd("lock-screen")
    -- Own shell (bar, notifications, OSD, power menu): ~/.config/quickshell/
    hl.exec_cmd("qs")
    -- Lock on suspend / idle: ~/.config/hypr/hypridle.conf
    hl.exec_cmd("hypridle")
    -- Walker + elephant (user services). With the uwsm session graphical-session.target
    -- already starts them; with the plain "Hyprland" session it does not. If they are
    -- running, systemctl start does nothing. PATH is passed so walker finds the scripts
    -- in ~/.local/bin (added by env.lua).
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP PATH && systemctl --user start elephant.service walker.service")

    -- Apps
    hl.exec_cmd("steam")
    hl.exec_cmd("rog-control-center")
    hl.exec_cmd("discord")
end)
