#!/usr/bin/env bash
# ==============================================================================
# screenshot.sh - Robust Wayland Screenshot & Annotation Handler
# Supports direct instant capture and interactive Satty annotation
# ==============================================================================

set -euo pipefail

MODE="${1:-region}"

SHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SHOT_DIR"
FILENAME="Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
TARGET_FILE="$SHOT_DIR/$FILENAME"
TEMP_FILE="/tmp/snip_$$.png"

cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# ------------------------------------------------------------------------------
# Mode: Direct instant fullscreen capture (no satty editor)
# ------------------------------------------------------------------------------
if [ "$MODE" = "direct" ] || [ "$MODE" = "screen-direct" ] || [ "$MODE" = "fullscreen-direct" ]; then
    if ! command -v grim &>/dev/null; then
        notify-send -a "Screenshot" -u critical "Screenshot Error" "'grim' is required for capturing screenshots."
        exit 1
    fi
    grim "$TARGET_FILE"
    if [ -f "$TARGET_FILE" ]; then
        wl-copy < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved" "Captured full screen to clipboard & saved to ~/Pictures/Screenshots/$FILENAME"
    fi
    exit 0
fi

# ------------------------------------------------------------------------------
# Geometry Resolution
# ------------------------------------------------------------------------------
GEOM=""

case "$MODE" in
    region|area)
        if ! command -v slurp &>/dev/null; then
            notify-send -a "Screenshot" -u critical "Screenshot Error" "'slurp' is required for region selection."
            exit 1
        fi
        # Select region with clean dark-frosted overlay and accent border
        GEOM=$(slurp -d -b "#0c0e14aa" -c "#7aa2f7ff" -s "#7aa2f722" -w 2 2>/dev/null || true)
        if [ -z "$GEOM" ]; then
            # User cancelled selection
            exit 0
        fi
        ;;
    window)
        # 1. Try to get active window from Hyprland
        if command -v hyprctl &>/dev/null; then
            GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r 'if .at and .size and .at[0] >= 0 then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end' 2>/dev/null || true)
        fi
        # 2. If no active window or hyprctl failed, let user click a window
        if [ -z "$GEOM" ] && command -v slurp &>/dev/null && command -v hyprctl &>/dev/null; then
            GEOM=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null | slurp -d -b "#0c0e14aa" -c "#7aa2f7ff" -s "#7aa2f722" -w 2 2>/dev/null || true)
        fi
        # 3. Fallback to interactive region selection
        if [ -z "$GEOM" ] && command -v slurp &>/dev/null; then
            GEOM=$(slurp -d -b "#0c0e14aa" -c "#7aa2f7ff" -s "#7aa2f722" -w 2 2>/dev/null || true)
            if [ -z "$GEOM" ]; then exit 0; fi
        fi
        ;;
    output|screen|fullscreen)
        GEOM=""
        ;;
    *)
        echo "Unknown mode: $MODE (available: direct, region, window, output)"
        exit 1
        ;;
esac

# Capture via grim
if ! command -v grim &>/dev/null; then
    notify-send -a "Screenshot" -u critical "Screenshot Error" "'grim' is required for capturing screenshots."
    exit 1
fi

# 1. Snap image directly to TEMP_FILE first
if [ -n "$GEOM" ]; then
    grim -g "$GEOM" "$TEMP_FILE"
else
    grim "$TEMP_FILE"
fi

if [ ! -f "$TEMP_FILE" ] || [ ! -s "$TEMP_FILE" ]; then
    exit 0
fi

# 2. Annotation & Markup Flow via satty
if command -v satty &>/dev/null; then
    # Launch satty with the captured file
    satty -f "$TEMP_FILE" \
          --output-filename "$TARGET_FILE" \
          --early-exit \
          --save-after-copy \
          --copy-command "wl-copy" \
          --disable-notifications

    # Only send notification if user copied or saved to TARGET_FILE
    if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
        wl-copy < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved" "Image copied to clipboard & saved to ~/Pictures/Screenshots/$FILENAME"
    fi
elif command -v swappy &>/dev/null; then
    swappy -f "$TEMP_FILE" -o "$TARGET_FILE"
    if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
        wl-copy < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved & Copied" "Saved to ~/Pictures/Screenshots/$FILENAME"
    fi
else
    # Direct fallback if markup editor is not installed
    cp "$TEMP_FILE" "$TARGET_FILE"
    wl-copy < "$TARGET_FILE" 2>/dev/null || true
    notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved & Copied" "Saved to ~/Pictures/Screenshots/$FILENAME\n\nInstall 'satty' for instant markup: sudo pacman -S satty"
fi
