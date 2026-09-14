-- ==========================================
-- Keybindings Configuration
-- ~/.config/hypr/keybinds.lua
-- ==========================================
local terminal = "ghostty"
local fileManager = "nautilus"
local browser = "zen-browser"
local mainMod = "SUPER"
-- Applications
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + Space", hl.dsp.global("quickshell:launcher_toggle"))
-- Window Management & Scripts
hl.bind(mainMod .. " + W", hl.dsp.window.close())
hl.bind(mainMod .. " + H", hl.dsp.global("quickshell:bar_toggle"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:wallpaper_toggle"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.global("quickshell:theme_toggle"))
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + L", hl.dsp.global("quickshell:lock"))
-- Screenshots (Quickshell independent instance with satty markup)
hl.bind("Print", hl.dsp.global("quickshell:screenshot_direct"))
hl.bind("SHIFT + Print", hl.dsp.global("quickshell:screenshot_toggle"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.global("quickshell:screenshot_toggle"))
hl.bind(mainMod .. " + Print", hl.dsp.global("quickshell:screenshot_window"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.global("quickshell:screenshot_region"))
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:clipboard_toggle"))
-- Focus 
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Workspaces
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Mouse Workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse Binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==========================================
-- Media & OSD Controls (Hold to adjust)
-- ==========================================

-- Volume & Audio OSD Binds
hl.bind("XF86AudioRaiseVolume", hl.dsp.global("quickshell:osd_volume_up"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.global("quickshell:osd_volume_down"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.global("quickshell:osd_volume_mute"), { repeating = false })
hl.bind("XF86AudioMicMute", hl.dsp.global("quickshell:osd_mic_mute"), { repeating = false })

-- Brightness OSD Binds (Display & Keyboard)
hl.bind("XF86MonBrightnessUp", hl.dsp.global("quickshell:osd_brightness_up"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("quickshell:osd_brightness_down"), { repeating = true })
hl.bind("XF86KbdBrightnessUp", hl.dsp.global("quickshell:osd_kbd_brightness_up"), { repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.global("quickshell:osd_kbd_brightness_down"), { repeating = true })

-- Media Playback Controls
hl.bind("XF86AudioPlay", hl.dsp.global("quickshell:osd_media_play_pause"), { repeating = false })
hl.bind("XF86AudioNext", hl.dsp.global("quickshell:osd_media_next"), { repeating = false })
hl.bind("XF86AudioPrev", hl.dsp.global("quickshell:osd_media_prev"), { repeating = false })
