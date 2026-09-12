import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    property bool isOpen: false
    property string currentWallpaper: ""
    property var wallpapers: []
    property int selectedIndex: 0

    property var tempWallpapers: []

    // Process to scan wallpapers
    Process {
        id: scanProc
        command: [
            "sh", "-c",
            "find /home/pavan/Pictures/Wallpapers -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \\) | sort"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line) return;
                line = line.trim();
                if (!line) return;
                let parts = line.split("/");
                let name = parts[parts.length - 1];
                root.tempWallpapers.push({ path: line, name: name });
            }
        }
        onExited: {
            root.wallpapers = root.tempWallpapers;
            // Update selected index to current active wallpaper if found
            for (let i = 0; i < root.wallpapers.length; i++) {
                if (root.wallpapers[i].path === root.currentWallpaper) {
                    root.selectedIndex = i;
                    break;
                }
            }
        }
    }

    // Process to query active wallpaper from swww/awww
    Process {
        id: queryProc
        command: [
            "sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH\"; " +
            "cmd=$(which swww 2>/dev/null || which awww 2>/dev/null || echo '/usr/bin/awww'); " +
            "\"$cmd\" query 2>/dev/null | grep -o 'image: .*' | cut -d' ' -f2-"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (line) {
                    root.currentWallpaper = line;
                }
            }
        }
    }

    // Process to apply wallpaper
    Process {
        id: applyProc
    }

    function refresh() {
        root.tempWallpapers = [];
        queryProc.running = false;
        queryProc.running = true;
        scanProc.running = false;
        scanProc.running = true;
    }

    function open() {
        Theme.closePopup();
        refresh();
        isOpen = true;
    }

    function close() {
        isOpen = false;
    }

    function toggle() {
        if (isOpen) {
            close();
        } else {
            open();
        }
    }

    function applyIndex(idx, keepOpen) {
        if (idx < 0 || idx >= wallpapers.length) return;
        let wp = wallpapers[idx];
        applyWallpaper(wp.path, keepOpen);
    }

    Process {
        id: ensureDaemonProc
        onExited: {
            root.refresh();
        }
    }

    function applyWallpaper(path, keepOpen) {
        if (!path) return;
        currentWallpaper = path;

        let effects = ["wipe", "wave", "grow", "center", "outer", "fade", "left", "right", "top", "bottom"];
        let randType = effects[Math.floor(Math.random() * effects.length)];
        let randAngle = Math.floor(Math.random() * 360);

        applyProc.command = [
            "sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH\"; " +
            "if ! pgrep -x awww-daemon >/dev/null && ! pgrep -x swww-daemon >/dev/null; then awww-daemon --quiet 2>/dev/null & sleep 0.25; fi; " +
            "cmd=$(which swww 2>/dev/null || which awww 2>/dev/null || echo '/usr/bin/awww'); " +
            "\"$cmd\" img " + JSON.stringify(path) +
            " --transition-type " + randType +
            " --transition-angle " + randAngle +
            " --transition-step 90 --transition-fps 60"
        ];
        applyProc.running = true;

        if (!keepOpen) {
            close();
        }
    }

    function applyRandom() {
        if (wallpapers.length === 0) return;
        let randIdx = Math.floor(Math.random() * wallpapers.length);
        selectedIndex = randIdx;
        applyIndex(randIdx, true);
    }

    Component.onCompleted: {
        ensureDaemonProc.command = [
            "sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:/usr/bin:$PATH\"; " +
            "if ! pgrep -x awww-daemon >/dev/null && ! pgrep -x swww-daemon >/dev/null; then awww-daemon --quiet 2>/dev/null & sleep 0.2; fi"
        ];
        ensureDaemonProc.running = true;
    }

    // ==========================================
    // HYPRLAND GLOBAL SHORTCUTS
    // ==========================================
    GlobalShortcut {
        appid: "quickshell"
        name: "wallpaper_toggle"
        onPressed: root.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "toggle_wallpaper"
        onPressed: root.toggle()
    }
}

