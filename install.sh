#!/usr/bin/env bash
# ==============================================================================
# myshell - Setup and Installation Script
# Symlinks desktop configurations (Hyprland, Quickshell, Ghostty) into ~/.config
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Colors for terminal output
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}${BOLD}[myshell]${RESET} $*"; }
log_success() { echo -e "${GREEN}${BOLD}[myshell]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}${BOLD}[myshell]${RESET} $*"; }
log_error()   { echo -e "${RED}${BOLD}[myshell]${RESET} $*"; }

link_component() {
    local name="$1"
    local src="$REPO_DIR/$name"
    local dest="$CONFIG_DIR/$name"

    if [ ! -d "$src" ]; then
        log_error "Source directory '$src' not found!"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"

    if [ -L "$dest" ]; then
        local current_target
        current_target="$(readlink -f "$dest")"
        if [ "$current_target" = "$src" ]; then
            log_info "$name is already linked to $src."
            return 0
        else
            log_warn "Updating existing symlink for $name..."
            rm "$dest"
        fi
    elif [ -e "$dest" ]; then
        local backup="${dest}.bak.$(date +%s)"
        log_warn "Existing $dest found. Backing up to $backup..."
        mv "$dest" "$backup"
    fi

    ln -sfn "$src" "$dest"
    log_success "Symlinked $dest -> $src"
}

check_dependencies() {
    log_info "Verifying core dependencies..."

    local pacman_pkgs=(
        "hyprland"
        "quickshell"
        "awww"
        "ghostty"
        "brightnessctl"
        "wl-clipboard"
        "cliphist"
        "playerctl"
        "wireplumber"
        "pipewire"
        "networkmanager"
        "bluez"
        "bluez-utils"
        "polkit-gnome"
        "asusctl"
    )

    local aur_pkgs=(
        "apple-fonts"
        "zen-browser-bin"
    )

    local missing=()
    for cmd in hyprland quickshell awww ghostty brightnessctl wl-copy cliphist playerctl pactl nmcli bluetoothctl asusctl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        log_success "All essential tools are installed and available in PATH!"
    else
        log_warn "The following commands were not found in PATH: ${missing[*]}"
        echo ""
        echo "To install missing packages on Arch Linux, run:"
        echo -e "  ${BOLD}sudo pacman -S --needed ${pacman_pkgs[*]}${RESET}"
        echo -e "  ${BOLD}yay -S --needed ${aur_pkgs[*]}${RESET}"
        echo ""
    fi
}

main() {
    echo -e "${BOLD}====================================================${RESET}"
    echo -e "${BOLD}        myshell - Desktop Configuration Setup       ${RESET}"
    echo -e "${BOLD}====================================================${RESET}"

    # 1. Symlink configurations
    log_info "Creating symlinks in $CONFIG_DIR..."
    link_component "quickshell"
    link_component "hypr"
    link_component "ghostty"

    # 2. Permissions
    log_info "Ensuring helper scripts are executable..."
    chmod +x "$REPO_DIR/quickshell/start.sh"
    chmod +x "$REPO_DIR/quickshell/scripts/sync-apps.py"
    log_success "Script permissions verified."

    # 3. Wallpaper directory
    mkdir -p "$HOME/Pictures/Wallpapers"
    log_info "Wallpaper directory ready at: $HOME/Pictures/Wallpapers"

    # 4. Zen Browser & App theme sync
    if command -v python3 &>/dev/null; then
        log_info "Synchronizing application palettes and browser styles..."
        python3 "$REPO_DIR/quickshell/scripts/sync-apps.py" || log_warn "sync-apps encountered a non-fatal warning."
    fi

    # 5. Dependency check
    check_dependencies

    echo -e "${GREEN}${BOLD}Setup completed successfully!${RESET}"
    echo ""
    echo "To start or restart the Quickshell environment:"
    echo "  $REPO_DIR/quickshell/start.sh restart"
    echo ""
}

main "$@"
