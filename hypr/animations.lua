

hl.config({ animations = { enabled = true } })
-- Popup fades
hl.animation({ leaf = "fadePopups", enabled = false })

hl.curve("macOSGlide", { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })

hl.animation({
    leaf = "global",
    enabled = true,
    speed = 5.5,
    bezier = "macOSGlide",
})
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 1.0,
    bezier = "default",
})
