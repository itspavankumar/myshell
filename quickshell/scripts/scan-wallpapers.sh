#!/usr/bin/env bash
# ==============================================================================
# scan-wallpapers.sh - Theme-Aware Wallpaper Scanner for Quickshell
# Resolves theme-specific wallpaper subdirectories in ~/Pictures/Wallpapers
# ==============================================================================

set -euo pipefail

THEME="${1:-}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

if [ -z "$THEME" ] && [ -f "$CONFIG_DIR/theme/active_theme.txt" ]; then
    THEME="$(tr -d '[:space:]' < "$CONFIG_DIR/theme/active_theme.txt")"
fi
THEME="${THEME:-tokyo-night}"

WALL_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Wallpapers"

if [ ! -d "$WALL_DIR" ]; then
    mkdir -p "$WALL_DIR"
    exit 0
fi

# Candidate folder mappings per theme
candidates=()
case "$THEME" in
    "tokyo-night")
        candidates=("Tokyo Night" "Tokyo-Night" "tokyo-night" "TokyoNight")
        ;;
    "catppuccin")
        candidates=("Catppuccin" "catppuccin" "Catppuccin Mocha" "catppuccin-mocha")
        ;;
    "nord")
        candidates=("Nord" "nord")
        ;;
    "everforest")
        candidates=("Everforest" "everforest")
        ;;
    "gruvbox")
        candidates=("Gruvbox" "gruvbox" "Minimal")
        ;;
    "solitude"|"matte-black"|"vantablack"|"lupine")
        candidates=("$THEME" "Minimal" "minimal")
        ;;
    "osaka-jade")
        candidates=("Osaka Jade" "osaka-jade" "Everforest" "Minimal")
        ;;
    "ristretto")
        candidates=("Ristretto" "ristretto" "Gruvbox" "Minimal")
        ;;
    *)
        candidates=("$THEME" "Minimal")
        ;;
esac

count_images() {
    local dir="$1"
    find "$dir" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
        -iname '*.webp' -o -iname '*.gif' \
    \) 2>/dev/null | wc -l
}

TARGET_DIR=""

# 1. Search theme candidates
for c in "${candidates[@]}"; do
    if [ -d "$WALL_DIR/$c" ]; then
        if [ "$(count_images "$WALL_DIR/$c")" -gt 0 ]; then
            TARGET_DIR="$WALL_DIR/$c"
            break
        fi
    fi
done

# 2. Fallback to Minimal
if [ -z "$TARGET_DIR" ] && [ -d "$WALL_DIR/Minimal" ]; then
    if [ "$(count_images "$WALL_DIR/Minimal")" -gt 0 ]; then
        TARGET_DIR="$WALL_DIR/Minimal"
    fi
fi

# 3. Fallback to any non-empty subfolder
if [ -z "$TARGET_DIR" ]; then
    for d in "$WALL_DIR"/*/; do
        if [ -d "$d" ] && [ "$(count_images "$d")" -gt 0 ]; then
            TARGET_DIR="${d%/}"
            break
        fi
    done
fi

# 4. Ultimate fallback to root Wallpapers folder
if [ -z "$TARGET_DIR" ]; then
    TARGET_DIR="$WALL_DIR"
fi

# Output FOLDER header
echo "FOLDER:$(basename "$TARGET_DIR")"

# Output list of files
find "$TARGET_DIR" -maxdepth 1 -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
    -iname '*.webp' -o -iname '*.gif' \
\) | sort
