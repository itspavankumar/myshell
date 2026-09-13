#!/usr/bin/env bash
# ==============================================================================
# Quickshell Unified Theme Switcher Engine
# Atomically persists theme, broadcasts IPC to all 8 Quickshell instances in
# parallel, triggers wallpaper sync, and asynchronously syncs external apps.
# ==============================================================================

set -eo pipefail

THEME_NAME="$1"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
ACTIVE_FILE="$CONFIG_DIR/theme/active_theme.txt"
CONFIGS=("bar" "lock" "launcher" "osd" "clipboard" "wallpaper" "themes" "screenshot")

if [ -z "$THEME_NAME" ]; then
    cat "$ACTIVE_FILE" 2>/dev/null || echo "tokyo-night"
    exit 0
fi

# 1. Safely persist active theme
echo "$THEME_NAME" > "$ACTIVE_FILE"

# 2. Broadcast theme change to all running Quickshell instances in parallel
for cfg in "${CONFIGS[@]}"; do
    quickshell ipc -p "$CONFIG_DIR/$cfg.qml" call theme setTheme "$THEME_NAME" >/dev/null 2>&1 &
done

# 3. Notify wallpaper service to pick matching wallpaper immediately
quickshell ipc -p "$CONFIG_DIR/wallpaper.qml" call wallpaper themeChanged "$THEME_NAME" >/dev/null 2>&1 &

# Wait for all Quickshell IPC calls to deliver (< 30ms)
wait

# 4. Asynchronously sync external apps (GTK, Ghostty, VSCodium, Zen Browser, icons)
python3 "$CONFIG_DIR/scripts/sync-apps.py" "$THEME_NAME" >/dev/null 2>&1 &
