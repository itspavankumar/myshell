-- ~/.config/hypr/layerrules.lua

-- Quickshell specific rules
-- Blur rules for the bar and its popups
hl.layer_rule({
    match = { namespace = "qs:bar" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.1,
    xray = true,
    no_anim = true 
})
-- Blur rules for the OSD
hl.layer_rule({
    match = { namespace = "qs:osd" },
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true
})
hl.layer_rule({
    match = { namespace = "qs:spotlight" },
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true
})
-- Blur rules for the Notification OSD
hl.layer_rule({
    match = { namespace = "qs:notif_osd" },
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true
})

-- Remove animations on the slurp region selection used by screenshots
hl.layer_rule({
    match = { namespace = "selection" },
    no_anim = true,
    animation = "none"
})

