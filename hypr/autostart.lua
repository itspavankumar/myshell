-- ~/.config/hypr/autostart.lua

hl.on("hyprland.start", function()
    -- System and Wayland environment setup
    local polkit_agent = "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    -- Core components/
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.config/quickshell/start.sh")
    hl.exec_cmd(polkit_agent)
    hl.exec_cmd("pactl load-module module-switch-on-connect")
    hl.exec_cmd("awww-daemon --quiet")
    
    -- UI, Wallpapers, and Clipboard
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("hyprctl setcursor macOS-White 16")
end)
