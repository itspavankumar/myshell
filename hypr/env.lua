hl.config({
	env = {
        -- Enable the Hyprcursor ecosystem
        "HYPRCURSOR_THEME,macOS-White",
        "HYPRCURSOR_SIZE,16",
        
        -- Fallback for older XWayland apps
        "XCURSOR_THEME,macOS-White",
        "XCURSOR_SIZE,16",
        "PATH,$HOME/.local/bin:$HOME/Projects/myshell/bin:$PATH",
	"QT_QPA_PLATFORMTHEME", "qt5ct",
	"QT_QPA_PLATFORMTHEME", "qt6ct",
        -- Other variables
        "_JAVA_AWT_WM_NONREPARENTING,1",
        "MOZ_ENABLE_WAYLAND,1",
        "QT_QPA_PLATFORM,wayland",
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1",
        "GDK_BACKEND,wayland,x11",
	"ELECTRON_OZONE_PLATFORM_HINT", "auto",
	
	--Portals
	"XDG_CURRENT_DESKTOP,Hyprland",
        "XDG_SESSION_TYPE,wayland",
        "XDG_SESSION_DESKTOP,Hyprland"
        }
})

