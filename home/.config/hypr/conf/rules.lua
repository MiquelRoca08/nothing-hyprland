-- Window and workspace rules — https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Walker appears and disappears without animation
hl.layer_rule({
    name  = "walker-no-anim",
    match = { namespace = "^walker$" },
    no_anim = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- The shell's Settings window: floating, centered
hl.window_rule({
    name  = "qs-ajustes",
    match = { title = "^Ajustes$" },
    float  = true,
    center = true,
    size   = "1140 780",
})

-- The system menu's terminal (update, install…): floating, centered
hl.window_rule({
    name  = "menu-terminal",
    match = { class = "^menu-terminal$" },
    float  = true,
    center = true,
    size   = "1000 640",
})

-- TUIs created with «tui crear» in floating mode (≈ Omarchy's floating-window)
hl.window_rule({
    name  = "tui-flotante",
    match = { class = "^TUI\\.float$" },
    float  = true,
    center = true,
    size   = "875 600",
})
