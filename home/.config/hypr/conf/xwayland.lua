-- XWayland — https://wiki.hypr.land/Configuring/Basics/Variables/#xwayland
-- X11 apps (Steam…) at the right size on both monitors: Hyprland upscales them
-- on the scale-2 screen, with bilinear filtering (smooth) instead of pixelated.

hl.config({
    xwayland = {
        force_zero_scaling   = false,
        use_nearest_neighbor = false,
    },
})
