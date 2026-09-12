pragma Singleton
import QtQuick

QtObject {
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
    readonly property int barMarginTop: 0
    readonly property int barMarginLeft: 0
    readonly property int barMarginRight: 0
    readonly property int squareRadius: 0 // True square borders as requested
    readonly property int microRadius: 2  // Subtle 2px bevel option if desired
    readonly property int borderWidth: 1
    
    // Color Palette (Caelestia / Noctalia / Tokyo Night inspired)
    readonly property color bgBase: "#0c0e14"
    readonly property color bgGlass: "#eb0e1017"
    readonly property color bgSurface: "#161822"
    readonly property color bgSurfaceHover: "#202331"
    readonly property color bgSurfaceActive: "#2a2e40"
    
    // Borders & Dividers
    readonly property color borderDim: "#222533"
    readonly property color borderNormal: "#2e3245"
    readonly property color borderBright: "#454a65"
    readonly property color borderAccent: "#7aa2f7"
    
    // Accents & Signals
    readonly property color cyan: "#7dcfff"
    readonly property color blue: "#7aa2f7"
    readonly property color purple: "#bb9af7"
    readonly property color magenta: "#f7768e"
    readonly property color green: "#9ece6a"
    readonly property color yellow: "#e0af68"
    readonly property color orange: "#ff9e64"
    readonly property color red: "#f7768e"
    
    // Typography Spacing & Tracking (Character separation)
    readonly property real trackingTight: 0.3
    readonly property real trackingNormal: 0.6
    readonly property real trackingLoose: 1.0
    readonly property real trackingWide: 1.4

    // Text Hierarchy (Crisp contrast for maximum legibility)
    readonly property color textPrimary: "#d5deff"
    readonly property color textSecondary: "#a9b6e5"
    readonly property color textMuted: "#7982a9"
    readonly property color textDark: "#15161e"

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
