pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "."

Item {
    id: root

    // Dynamic Active Theme State (Persisted)
    property string currentTheme: "tokyo-night"
    readonly property var activePalette: Palettes.get(currentTheme)

    // Live file watcher for theme changes across all modular instances
    Timer {
        id: watcherRetryTimer
        interval: 50
        repeat: false
        onTriggered: {
            let t = themeWatcher.text().trim();
            if (t && Palettes.list.includes(t) && root.currentTheme !== t) {
                root.currentTheme = t;
            }
        }
    }

    FileView {
        id: themeWatcher
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/theme/active_theme.txt"
        watchChanges: true
        onFileChanged: {
            let t = themeWatcher.text().trim();
            if (t && Palettes.list.includes(t) && root.currentTheme !== t) {
                root.currentTheme = t;
            } else if (!t) {
                watcherRetryTimer.restart();
            }
        }
        onLoaded: {
            let t = themeWatcher.text().trim();
            if (t && Palettes.list.includes(t)) {
                root.currentTheme = t;
            }
        }
    }

    property string pendingTheme: ""

    // Process to run unified theme switch script
    Process {
        id: persistAndSyncProc
        onExited: {
            if (root.pendingTheme !== "" && root.pendingTheme !== root.currentTheme) {
                let next = root.pendingTheme;
                root.pendingTheme = "";
                root.setTheme(next);
            }
        }
    }

    IpcHandler {
        target: "theme"

        function setTheme(name: string): void {
            if (Palettes.list.includes(name) && root.currentTheme !== name) {
                root.currentTheme = name;
            }
        }

        function getTheme(): string {
            return root.currentTheme;
        }
    }

    function setTheme(themeId) {
        if (!Palettes.list.includes(themeId)) return;
        currentTheme = themeId;

        if (persistAndSyncProc.running) {
            pendingTheme = themeId;
            return;
        }

        let scriptPath = (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/set-theme.sh";
        persistAndSyncProc.command = ["bash", scriptPath, themeId];
        persistAndSyncProc.running = true;
    }

    // Fonts (Apple San Francisco Optical System)
    readonly property string fontFamily: "SF Pro Text"
    readonly property string fontDisplay: "SF Pro Display"
    readonly property string fontText: "SF Pro Text"
    readonly property string fontMono: "SF Mono"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
    
    // Text Rendering Engine (Native FreeType subpixel rendering for maximum sharpness on 1080p)
    readonly property int renderType: Text.NativeRendering

    // Apple HIG Typography Scale (Optimized for 1080p 1.0x display)
    readonly property int fontHero: 24        // Clock digits, hero metrics
    readonly property int fontTitle: 15       // Main popup headers, spotlight search
    readonly property int fontHeadline: 13    // Tile primary labels, bar clock, card titles
    readonly property int fontBody: 12        // List titles, slider labels, app names
    readonly property int fontSubhead: 11     // Subtitles, gamut, descriptions, action buttons
    readonly property int fontCaption: 10     // Badges, pill tags, uppercase section headers

    // Core Sizing & Layout (Crisp, Square Geometry)
    readonly property int barHeight: 25
    readonly property int moduleHeight: barHeight - 8 // 17px unified module height
    readonly property int barMarginTop: 3
    readonly property int barMarginLeft: 3
    readonly property int barMarginRight: 3
    readonly property int squareRadius: 0 // True square borders as requested
    readonly property int microRadius: 2  // Subtle 2px bevel option if desired
    readonly property int borderWidth: 1
    
    // Color Palette (Dynamic from activePalette)
    readonly property color bgBase: activePalette.bgBase
    readonly property color bgGlass: activePalette.bgGlass
    readonly property color bgSurface: activePalette.bgSurface
    readonly property color bgSurfaceHover: activePalette.bgSurfaceHover
    readonly property color bgSurfaceActive: activePalette.bgSurfaceActive
    
    // Borders & Dividers
    readonly property color borderDim: activePalette.borderDim
    readonly property color borderNormal: activePalette.borderNormal
    readonly property color borderBright: activePalette.borderBright
    readonly property color borderAccent: activePalette.borderAccent
    
    // Accents & Signals
    readonly property color accent: activePalette.accent
    readonly property color cyan: activePalette.cyan
    readonly property color blue: activePalette.blue
    readonly property color purple: activePalette.purple
    readonly property color magenta: activePalette.magenta
    readonly property color green: activePalette.green
    readonly property color yellow: activePalette.yellow
    readonly property color orange: activePalette.orange
    readonly property color red: activePalette.red
    
    // Typography Spacing & Tracking (Character separation)
    readonly property real trackingTight: 0.3
    readonly property real trackingNormal: 0.6
    readonly property real trackingLoose: 1.0
    readonly property real trackingWide: 1.4

    // Text Hierarchy (Crisp contrast for maximum legibility)
    readonly property color textPrimary: activePalette.textPrimary
    readonly property color textSecondary: activePalette.textSecondary
    readonly property color textMuted: activePalette.textMuted
    readonly property color textDark: activePalette.textDark

    // Unified Popup Management
    readonly property int popupMarginTop: 8
    property string activePopup: ""

    function togglePopup(name) {
        if (activePopup === name) {
            activePopup = "";
        } else {
            activePopup = name;
        }
    }

    function closePopup() {
        activePopup = "";
    }

    // Bar Visibility State
    property bool barVisible: true

    function toggleBar() {
        barVisible = !barVisible;
        if (!barVisible) {
            closePopup();
        }
    }

    function showBar() {
        barVisible = true;
    }

    function hideBar() {
        barVisible = false;
        closePopup();
    }

    // Session Locking
    signal requestLock()

    function lock() {
        requestLock();
    }
}
