#!/usr/bin/env bash
# ==============================================================================
# screenshot.sh - Robust Wayland Screenshot & Annotation Handler
# Supports direct instant capture, interactive window click, and Satty markup
# ==============================================================================

set -euo pipefail

MODE="${1:-region}"

SHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SHOT_DIR"
FILENAME="Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"
TARGET_FILE="$SHOT_DIR/$FILENAME"

# ------------------------------------------------------------------------------
# Mode: Direct instant fullscreen capture (Print hotkey)
# ------------------------------------------------------------------------------
if [ "$MODE" = "direct" ] || [ "$MODE" = "screen-direct" ] || [ "$MODE" = "fullscreen-direct" ]; then
    if ! command -v grim &>/dev/null; then
        notify-send -a "Screenshot" -u critical "Screenshot Error" "'grim' is required for capturing screenshots."
        exit 1
    fi
    grim "$TARGET_FILE"
    if [ -f "$TARGET_FILE" ]; then
        wl-copy --type image/png < "$TARGET_FILE" 2>/dev/null || true
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
        # Select region with clean dark-frosted overlay and cyan accent border
        GEOM=$(slurp -d -b "#0c0e14aa" -c "#7aa2f7ff" -s "#7aa2f722" -w 2 2>/dev/null || true)
        if [ -z "$GEOM" ]; then
            # User cancelled selection
            exit 0
        fi
        ;;
    window)
        if ! command -v slurp &>/dev/null; then
            notify-send -a "Screenshot" -u critical "Screenshot Error" "'slurp' is required for window selection."
            exit 1
        fi

        # Extract geometry boxes of visible windows on the active workspace(s)
        boxes=""
        if command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
            monitors=$(hyprctl -j monitors 2>/dev/null || echo '[]')
            ws_ids=$(echo "$monitors" | jq -r '[.[].activeWorkspace.id] | join(",")')
            boxes=$(hyprctl -j clients 2>/dev/null | jq -r --arg ws "$ws_ids" '
                ($ws | split(",") | map(tonumber? // empty)) as $active_workspaces
                | .[]
                | select(.mapped == true and .hidden == false)
                | select(.workspace.id as $w | $active_workspaces | index($w))
                | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
            ' 2>/dev/null || true)
        fi

        if [ -n "$boxes" ]; then
            # Interactive click to select from open windows with purple accent border
            GEOM=$(echo "$boxes" | slurp -d -b "#0c0e14aa" -c "#bb9af7ff" -s "#bb9af722" -w 2 -r 2>/dev/null || true)
        else
            # Fallback to interactive selection if no window boxes found
            GEOM=$(slurp -d -b "#0c0e14aa" -c "#bb9af7ff" -s "#bb9af722" -w 2 2>/dev/null || true)
        fi

        if [ -z "$GEOM" ]; then
            # User cancelled window selection
            exit 0
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

# 1. Snap image directly to TARGET_FILE
if [ -n "$GEOM" ]; then
    grim -g "$GEOM" "$TARGET_FILE"
else
    grim "$TARGET_FILE"
fi

if [ ! -f "$TARGET_FILE" ] || [ ! -s "$TARGET_FILE" ]; then
    exit 0
fi

# 2. Immediately copy to clipboard and send notification
wl-copy --type image/png < "$TARGET_FILE" 2>/dev/null || true
notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Saved" "Captured to clipboard & saved to ~/Pictures/Screenshots/$FILENAME"

# 3. Annotation & Markup Flow via satty
if command -v satty &>/dev/null; then
    BEFORE_TIME=$(stat -c %Y "$TARGET_FILE" 2>/dev/null || echo 0)
    # Launch satty with the captured file
    satty -f "$TARGET_FILE" \
          --output-filename "$TARGET_FILE" \
          --early-exit \
          --save-after-copy \
          --copy-command "wl-copy" \
          --disable-notifications

    # If user edited and saved inside satty, update clipboard & notify
    AFTER_TIME=$(stat -c %Y "$TARGET_FILE" 2>/dev/null || echo 0)
    if [ "$AFTER_TIME" -gt "$BEFORE_TIME" ]; then
        wl-copy --type image/png < "$TARGET_FILE" 2>/dev/null || true
        notify-send -a "Screenshot" -i "$TARGET_FILE" "Screenshot Updated" "Annotated image saved & copied to clipboard"
    fi
elif command -v swappy &>/dev/null; then
    swappy -f "$TARGET_FILE" -o "$TARGET_FILE"
fi
