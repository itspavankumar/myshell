#!/usr/bin/env bash
# ==============================================================================
# Quickshell Caffeinate Controller
# Manages Keep-Awake state, systemd sleep inhibitors, and Quickshell IPC
# ==============================================================================

STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state/caffeinated.txt"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
mkdir -p "$(dirname "$STATE_FILE")"

ACTION="$1"
if [ -z "$ACTION" ]; then
    CURRENT=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
    if [ "$CURRENT" = "1" ]; then
        ACTION="off"
    else
        ACTION="on"
    fi
fi

if [ "$ACTION" = "on" ] || [ "$ACTION" = "1" ] || [ "$ACTION" = "true" ]; then
    echo "1" > "$STATE_FILE"
    # Start systemd inhibitor in background if not already active
    if ! pgrep -f "[s]ystemd-inhibit.*Quickshell Caffeinate" >/dev/null 2>&1; then
        systemd-inhibit --what=idle:sleep --why="Quickshell Caffeinate" sleep infinity >/dev/null 2>&1 &
    fi
    # Notify lock daemon
    quickshell ipc -p "$CONFIG_DIR/lock.qml" call lock setCaffeinated true >/dev/null 2>&1 || true
else
    echo "0" > "$STATE_FILE"
    # Terminate systemd inhibitor
    pkill -f "systemd-inhibit.*Quickshell Caffeinate" >/dev/null 2>&1 || true
    # Notify lock daemon
    quickshell ipc -p "$CONFIG_DIR/lock.qml" call lock setCaffeinated false >/dev/null 2>&1 || true
fi
