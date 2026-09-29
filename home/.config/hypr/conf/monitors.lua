-- Monitors — https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Rewritten by Settings → Displays on apply (only the hl.monitor blocks of connected monitors;
-- the others stay as they are). It can also be edited by hand: the form reads Hyprland's actual
-- values. Anything that is not hl.monitor is lost when applying from Settings.

hl.monitor({
    output    = "eDP-1",
    mode      = "2880x1800@120.00",
    position  = "0x0",
    scale     = 1.8,
    transform = 0,
    vrr       = 0,
    bitdepth  = 10,
})

hl.monitor({
    output    = "DP-9",
    mode      = "2560x1440@180.00",
    position  = "1600x-600",
    scale     = 1,
    transform = 0,
    vrr       = 0,
    bitdepth  = 10,
})
