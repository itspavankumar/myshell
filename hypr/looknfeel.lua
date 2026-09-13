-- ~/.config/hypr/looknfeel.lua

hl.config({
    -- General Layout & Borders
    general = {
        gaps_in = 2,
        gaps_out = 3,
        border_size = 0,
        ["col.active_border"] = "rgba(ffffff75)",
        ["col.inactive_border"] = "rgba(ffffff1a)",
        resize_on_border = true,
        extend_border_grab_area = 2,
        allow_tearing = true,
        layout = "scrolling",
        snap = {
            border_overlap = true,
            enabled = false,
            respect_gaps = true,
        }
    },
    -- Scrolling Layout Configuration
    scrolling = {
        column_width = 0.75, 
        focus_fit_method = 1
    },

    -- Window Decoration & Shadow
    decoration = {
        rounding = 0,
        rounding_power = 5,
        active_opacity = 0.7,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1,
        
        shadow = {
            enabled = true,
            range = 30,               
            render_power = 3,        
            color = "rgba(00000077)",
            color_inactive = "rgba(00000022)" 
        },
        
       blur = {
    		enabled = true,
    		size = 5,                 -- Increased from 6. Gives that deep, diffuse look.
    		passes = 3,                -- 3 is perfect.
    		ignore_opacity = true,
    		popups = true,
    		contrast = 1.7,            -- Lowered from 1.5. Keeps the gradient smooth.
    		brightness = 1,          -- Slightly dims the background to make white text pop.
    		vibrancy = 1,           -- Gently boosts the colors bleeding through the glass.
    		vibrancy_darkness = 0.1
	   }

    },

		
    -- Cursor Settings
    cursor = {
        hide_on_key_press = true,
        inactive_timeout = 20.0,
        no_warps = false,
        persistent_warps = true,
        warp_on_change_workspace = 0,
    },
    -- Tiling Options
    dwindle = {
        smart_split = true,
    },
    -- Hyprland Ecosystem
    ecosystem = {
        no_donation_nag = true,
        no_update_news = true,
    },
    -- Miscellaneous & XWayland
    misc = {
        animate_mouse_windowdragging = true,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
    },
    xwayland = {
        force_zero_scaling = true,
    }
})
