-- Misc — https://wiki.hypr.land/Configuring/Basics/Variables/#misc

hl.config({
    misc = {
        force_default_wallpaper = 0,     -- No Hyprland wallpapers: the shell sets the wallpaper
        disable_hyprland_logo   = true,
        -- Black until the shell draws the wallpaper and the lock screen: follows the boot logo
        background_color        = "rgb(000000)",
        -- If the shell crashes with the session locked, it restores the lock when relaunched
        -- (without this, Hyprland's emergency screen stays)
        allow_session_lock_restore = true,
    },
})
