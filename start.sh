#!/usr/bin/env bash
# ==============================================================================
# Quickshell Modular Process Supervisor
# Manages independent Quickshell instances for crash isolation.
# ==============================================================================

CONFIG_DIR="/home/pavan/.config/quickshell"
CONFIGS=("bar" "lock" "launcher" "osd" "clipboard" "wallpaper")

start_all() {
    echo "Starting modular Quickshell instances..."
    local list_output
    list_output=$(quickshell list --all 2>/dev/null || true)

    for cfg in "${CONFIGS[@]}"; do
        local qml_file="$CONFIG_DIR/$cfg.qml"
        if echo "$list_output" | grep -q "$qml_file"; then
            echo "  - $cfg: already running"
        else
            echo "  - starting $cfg"
            quickshell -p "$qml_file" -d
        fi
    done
    echo "All Quickshell instances started."
}

stop_all() {
    echo "Stopping all Quickshell instances..."
    pkill -x quickshell 2>/dev/null || true
    echo "All instances stopped."
}

restart_all() {
    stop_all
    sleep 0.4
    start_all
}

restart_one() {
    local target="$1"
    local qml_file="$CONFIG_DIR/$target.qml"
    if [ ! -f "$qml_file" ]; then
        echo "Error: Unknown component '$target'. Available: ${CONFIGS[*]}"
        exit 1
    fi
    echo "Restarting Quickshell component: $target"
    quickshell kill -p "$qml_file" 2>/dev/null || true
    sleep 0.25
    quickshell -p "$qml_file" -d
    echo "Restarted $target."
}

status() {
    quickshell list --all 2>/dev/null || echo "No Quickshell instances running."
}

case "$1" in
    stop)
        stop_all
        ;;
    restart)
        if [ -n "$2" ]; then
            restart_one "$2"
        else
            restart_all
        fi
        ;;
    status)
        status
        ;;
    *)
        start_all
        ;;
esac
