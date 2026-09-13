#!/usr/bin/env bash
# ==============================================================================
# screenshot.sh - Independent Wayland Screenshot & Markup Handler
# Replaces hyprshot with instant capture + markup annotation support (satty)
# ==============================================================================

set -euo pipefail

MODE="${1:-region}"
DELAY="${2:-0}"

SHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SHOT_DIR"
FILENAME="Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
TARGET_FILE="$SHOT_DIR/$FILENAME"

# Optional delay (in seconds)
if [ "$DELAY" -gt 0 ]; then
    sleep "$DELAY"
fi

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
        # Fullscreen / active monitor
        GEOM=""
        ;;
    *)
        echo "Unknown mode: $MODE (available: region, window, output)"
        exit 1
        ;;
esac

# Capture via grim
if ! command -v grim &>/dev/null; then
    notify-send -a "Screenshot" -u critical "Screenshot Error" "'grim' is required for capturing screenshots."
    exit 1
fi

# Markup / Annotation flow
if command -v satty &>/dev/null; then
    # Full Satty markup annotation editor
    if [ -n "$GEOM" ]; then
        grim -g "$GEOM" - | satty --filename - --output-filename "$TARGET_FILE" --early-exit --save-after-copy --copy-command "wl-copy"
    else
        grim - | satty --filename - --output-filename "$TARGET_FILE" --early-exit --save-after-copy --copy-command "wl-copy"
    fi
    if [ -f "$TARGET_FILE" ]; then
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved" "$TARGET_FILE"
    fi
elif command -v swappy &>/dev/null; then
    # Swappy markup editor fallback
    if [ -n "$GEOM" ]; then
        grim -g "$GEOM" - | swappy -f - -o "$TARGET_FILE"
    else
        grim - | swappy -f - -o "$TARGET_FILE"
    fi
    if [ -f "$TARGET_FILE" ]; then
        wl-copy < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved & Copied" "$TARGET_FILE"
    fi
else
    # Direct capture fallback if markup editor is not yet installed
    if [ -n "$GEOM" ]; then
        grim -g "$GEOM" "$TARGET_FILE"
    else
        grim "$TARGET_FILE"
    fi
    if [ -f "$TARGET_FILE" ]; then
        wl-copy < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved & Copied" "$TARGET_FILE\n\nInstall 'satty' for instant markup: sudo pacman -S satty"
    fi
fi
