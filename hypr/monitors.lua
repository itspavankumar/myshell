-- External display (HDMI), mirrors the internal display
hl.monitor({
    output = "HDMI-A-1",
    mode = "preferred",
    position = "auto",
    scale = 1,
    mirror = "eDP-1",
})
-- Enable Auto HDR for color management
hl.config({
  render = {
    cm_auto_hdr = 2,
  },
})

-- Primary internal display (eDP-1) with 10-bit color and brightness limits
hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60.00Hz",
    cm = "auto",
    scale = 1,
    bitdepth = 10,
    sdrbrightness = 1.5,
    sdr_min_luminance = 0,
    sdr_max_luminance = 617,
    min_luminance = 0,
    max_luminance = 617,
    max_avg_luminance = 400,
})
