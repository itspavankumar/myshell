import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Qt.labs.folderlistmodel
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

    // --------------------------------------------------------------------------
    // Folder & Image Scanners (Native Qt Quick inotify live watching)
    // --------------------------------------------------------------------------
    FolderListModel {
        id: dirModel
        folder: "file://" + (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
        showDirs: true
        showFiles: false
        showDotAndDotDot: false

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                root.resolveAndLoadFolder();
            }
        }
        onCountChanged: {
            root.resolveAndLoadFolder();
        }
    }

    FolderListModel {
        id: imageModel
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
        showFiles: true
        showDirs: false
        showDotAndDotDot: false

        onStatusChanged: {
            if (status === FolderListModel.Ready) {
                root.rebuildWallpapers();
            }
        }
        onCountChanged: {
            root.rebuildWallpapers();
        }
    }

    function getThemeCandidates(themeName) {
        switch (themeName) {
            case "tokyo-night":
                return ["Tokyo Night", "Tokyo-Night", "tokyo-night", "TokyoNight"];
            case "catppuccin":
                return ["Catppuccin", "catppuccin", "Catppuccin Mocha", "catppuccin-mocha"];
            case "nord":
                return ["Nord", "nord"];
            case "everforest":
                return ["Everforest", "everforest"];
            case "gruvbox":
                return ["Gruvbox", "gruvbox", "Minimal"];
            case "solitude":
            case "lupine":
                return [themeName, "Minimal", "minimal"];
            case "osaka-jade":
                return ["Osaka Jade", "osaka-jade", "Everforest", "Minimal"];
            case "ristretto":
                return ["Ristretto", "ristretto", "Gruvbox", "Minimal"];
            default:
                return [themeName, "Minimal"];
        }
    }

    function resolveAndLoadFolder() {
        let availableDirs = [];
        for (let i = 0; i < dirModel.count; i++) {
            availableDirs.push(dirModel.get(i, "fileName"));
        }

        let candidates = getThemeCandidates(Theme.currentTheme);
        let target = "";

        // 1. Search theme-specific candidate folders
        for (let c of candidates) {
            if (availableDirs.includes(c)) {
                target = c;
                break;
            }
        }

        // 2. Fallback to Minimal
        if (!target && availableDirs.includes("Minimal")) {
            target = "Minimal";
        }

        // 3. Fallback to first available subfolder
        if (!target && availableDirs.length > 0) {
            target = availableDirs[0];
        }

        root.activeFolder = target || "Wallpapers";

        let basePath = (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers";
        let targetUrl = target ? ("file://" + basePath + "/" + target) : ("file://" + basePath);

        if (imageModel.folder !== targetUrl) {
            imageModel.folder = targetUrl;
        } else {
            root.rebuildWallpapers();
        }
    }

    function rebuildWallpapers() {
        let list = [];
        for (let i = 0; i < imageModel.count; i++) {
            let fPath = imageModel.get(i, "filePath");
            let fName = imageModel.get(i, "fileName");
            if (fPath) {
                if (fPath.startsWith("file://")) fPath = fPath.substring(7);
                list.push({ path: fPath, name: fName || "" });
            }
        }

        root.wallpapers = list;

        // Sync selected index to current active wallpaper if found
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

    // --------------------------------------------------------------------------
    // Process to query active wallpaper from awww
    // --------------------------------------------------------------------------
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
        queryProc.running = false;
        queryProc.running = true;
        root.resolveAndLoadFolder();
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
            if (name && Palettes.list.includes(name) && Theme.currentTheme !== name) {
                Theme.currentTheme = name;
            }
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
