import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    property bool randomOnStartup: false
    property bool isOpen: false
    property string currentWallpaper: ""
    property var wallpapers: []
    property int selectedIndex: 0
    property string activeFolder: ""
    property bool applyRandomOnScan: false

    property var tempWallpapers: []

    // Process to scan wallpapers using theme-aware scanner
    Process {
        id: scanProc
        command: [
            (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/scan-wallpapers.sh",
            Theme.currentTheme
        ]
        stdout: SplitParser {
            onRead: (line) => {
                if (!line) return;
                line = line.trim();
                if (!line) return;
                if (line.startsWith("FOLDER:")) {
                    root.activeFolder = line.substring(7);
                    return;
                }
                let parts = line.split("/");
                let name = parts[parts.length - 1];
                root.tempWallpapers.push({ path: line, name: name });
            }
        }
        onExited: {
            root.wallpapers = root.tempWallpapers;
            // Update selected index to current active wallpaper if found
            let foundIndex = -1;
            for (let i = 0; i < root.wallpapers.length; i++) {
                if (root.wallpapers[i].path === root.currentWallpaper) {
                    foundIndex = i;
                    break;
                }
            }
            root.selectedIndex = (foundIndex !== -1) ? foundIndex : 0;

            if (root.randomOnStartup && root.wallpapers.length > 0) {
                root.randomOnStartup = false;
                root.applyRandom();
            } else if (root.applyRandomOnScan && root.wallpapers.length > 0) {
                root.applyRandomOnScan = false;
                root.applyRandom();
            }
        }
    }

    // Process to query active wallpaper from awww
    Process {
        id: queryProc
        command: ["awww", "query"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                let idx = line.indexOf("image: ");
                if (idx !== -1) {
                    let p = line.substring(idx + 7).trim();
                    if (p) {
                        root.currentWallpaper = p;
                    }
                }
            }
        }
    }

    // Process to apply wallpaper
    Process {
        id: applyProc
    }

    function refresh(applyRandom) {
        root.applyRandomOnScan = !!applyRandom;
        root.tempWallpapers = [];
        queryProc.running = false;
        queryProc.running = true;
        scanProc.command = [
            (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/scan-wallpapers.sh",
            Theme.currentTheme
        ];
        scanProc.running = false;
        scanProc.running = true;
    }

    function open() {
        Theme.closePopup();
        refresh(false);
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
            root.refresh(root.randomOnStartup);
        }
    }

    function applyWallpaper(path, keepOpen) {
        if (!path) return;
        currentWallpaper = path;

        let effects = ["wipe", "wave", "grow", "center", "outer", "fade", "left", "right", "top", "bottom"];
        let randType = effects[Math.floor(Math.random() * effects.length)];
        let randAngle = Math.floor(Math.random() * 360);

        applyProc.command = [
            "awww", "img", path,
            "--transition-type", randType,
            "--transition-angle", randAngle.toString(),
            "--transition-step", "90",
            "--transition-fps", "60"
        ];
        applyProc.running = true;

        if (!keepOpen) {
            close();
        }
    }

    function applyRandom() {
        if (wallpapers.length === 0) return;
        let randIdx = Math.floor(Math.random() * wallpapers.length);
        if (wallpapers.length > 1 && randIdx === selectedIndex) {
            randIdx = (randIdx + 1 + Math.floor(Math.random() * (wallpapers.length - 1))) % wallpapers.length;
        }
        selectedIndex = randIdx;
        applyIndex(randIdx, true);
    }

    // React to theme changes across the entire shell
    Connections {
        target: Theme
        function onCurrentThemeChanged() {
            root.refresh(true);
        }
    }

    Component.onCompleted: {
        ensureDaemonProc.command = [
            "sh", "-c",
            "if ! pgrep -x awww-daemon >/dev/null; then awww-daemon --quiet 2>/dev/null & sleep 0.2; fi"
        ];
        ensureDaemonProc.running = true;
    }

    // ==========================================
    // IPC HANDLER & HYPRLAND SHORTCUTS
    // ==========================================
    IpcHandler {
        target: "wallpaper"

        function random(): void {
            root.applyRandom();
        }

        function themeChanged(name: string): void {
            root.refresh(true);
        }

        function set(path: string): void {
            root.applyWallpaper(path, false);
        }

        function toggle(): void {
            root.toggle();
        }

        function get(): string {
            return root.currentWallpaper;
        }

        function getFolder(): string {
            return root.activeFolder;
        }
    }

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
