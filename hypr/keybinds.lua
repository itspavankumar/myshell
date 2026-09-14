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
-- ==============================================================================
-- Screenshots (Omarchy Capture Pipeline)
-- ==============================================================================
hl.bind("Print", hl.dsp.exec_cmd("omarchy-capture-screenshot"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("omarchy-capture-screenshot region"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("omarchy-capture-screenshot region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("omarchy-capture-screenshot windows"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("omarchy-capture-screenshot region"))
hl.bind(mainMod .. " + V", hl.dsp.global("quickshell:clipboard_toggle"))

-- Keyboard control for the slurp region picker (see omarchy-capture-region)
local selection_layers = 0
local selection_binds = {}

hl.on("layer.opened", function(layer)
  if layer.namespace == "selection" then
    selection_layers = selection_layers + 1
    if selection_layers == 1 then
      selection_binds = {
        hl.bind("RETURN", hl.dsp.exec_cmd("omarchy-capture-region --take-window"), { description = "Capture highlighted window" }),
        hl.bind("CTRL + RETURN", hl.dsp.exec_cmd("omarchy-capture-region --take-fullscreen"), { description = "Capture entire screen" }),
        hl.bind("TAB", hl.dsp.exec_cmd("omarchy-capture-region --select-window next"), { description = "Select next window to capture" }),
        hl.bind("CTRL + TAB", hl.dsp.exec_cmd("omarchy-capture-region --select-window prev"), { description = "Select previous window to capture" }),
      }
      for _, direction in ipairs({ "left", "right", "up", "down" }) do
        table.insert(
          selection_binds,
          hl.bind(direction:upper(), hl.dsp.exec_cmd("omarchy-capture-region --select-window " .. direction), { description = "Select window to capture" })
        )
      end
    end
  end
end)

hl.on("layer.closed", function(layer)
  if layer.namespace == "selection" and selection_layers > 0 then
    selection_layers = selection_layers - 1
    if selection_layers == 0 then
      for _, keybind in ipairs(selection_binds) do
        keybind:unbind()
      end
      selection_binds = {}
    end
  end
end)

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
