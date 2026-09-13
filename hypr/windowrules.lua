-- ~/.config/hypr/windowrules.lua

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
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})
-- 2. Floating Windows (match float = true)
hl.window_rule({
    match = { float = true },
    border_size = 1,  
    rounding = 10,
    rounding_power = 8,
})

hl.window_rule({
    match = { class = "^(org.gnome.Nautilus|com.mitchellh.ghostty)$" },
    float = true,
    center = true,       
    size = { 1000, 600 },    
})


-- File Picker & Portal Fix
hl.window_rule({
    name = "portal-fix",
    match = { 
        class = "^(xdg-desktop-portal-gtk|.*\\.portal.*)$",
        title = "^(Open File|Select a File|Choose Files|Save As|Confirm to replace files)$"
    },
    float = true,
    center = true,
    size = { 900, 600 }
})

-- GNOME Sushi
hl.window_rule({
    name = "gnome-sushi",
    match = { class = "(org.gnome.NautilusPreviewer)" },
    float = true,
})

-- Satty Screenshot Annotation Tool (Floating & Centered)
hl.window_rule({
    name = "satty-floating",
    match = { class = "^(com\\.gabm\\.satty|satty)$" },
    float = true,
    center = true,
    size = { 1200, 750 },
})
-- Remove borders and shadows for ONLYOFFICE to prevent rendering glitches
hl.window_rule({
    match = { class = "ONLYOFFICE" },
    border_size = 0,
    rounding = 0,
    no_shadow = true,
})

-- Quickshell Window Rules
hl.window_rule({
    match = { class = "quickshell" },
    no_shadow = true
})
