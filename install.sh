#!/usr/bin/env bash
# ==============================================================================
# myshell - Automated System Setup & Installer
# Transforms a minimal Arch Linux installation into a fully configured desktop:
# Hyprland (Lua) + Quickshell + Ghostty + Zen Browser + Nautilus + Unified Theming
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Styling
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

log_info()    { echo -e "${BLUE}${BOLD}[myshell]${RESET} $*"; }
log_success() { echo -e "${GREEN}${BOLD}[myshell]${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}${BOLD}[myshell]${RESET} $*"; }
log_error()   { echo -e "${RED}${BOLD}[myshell]${RESET} $*"; }
log_step()    { echo -e "\n${CYAN}${BOLD}==> $*${RESET}"; }

# Core Official Arch Packages (pacman)
PACMAN_PACKAGES=(
    # Audio & Multimedia
    pipewire
    pipewire-pulse
    pipewire-alsa
    wireplumber
    playerctl
    libpulse

    # Networking & Bluetooth
    networkmanager
    bluez
    bluez-utils

    # Compositor & Wayland Ecosystem
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
    qt6-5compat
    polkit-gnome

    # Shell, Terminal & Utilities
    quickshell
    ghostty
    awww
    brightnessctl
    wl-clipboard
    cliphist
    hyprshot
    libnotify
    upower
    xdg-user-dirs

    # Nautilus File Manager & Drive / Network Integration
    nautilus
    nautilus-python
    sushi
    ffmpegthumbnailer
    gst-thumbnailers
    gvfs
    gvfs-mtp
    gvfs-smb
    gvfs-gphoto2
    gvfs-dnssd
    zip
    unzip
    7zip

    # GNOME Core Apps (Themed via sync-apps.py)
    loupe
    showtime
    decibels
    snapshot
    gnome-calculator
    gnome-clocks
    gnome-system-monitor
    gnome-font-viewer
    gnome-music

    # Utilities & Tools
    mpv
    btop
    ncdu
    neovim
    nwg-look
    github-cli
    yt-dlp
    zsh

    # Theming & Fonts
    adw-gtk-theme
    ttf-jetbrains-mono-nerd
    noto-fonts-emoji
    otf-font-awesome

    # Build & Script Dependencies
    base-devel
    git
    curl
    jq
    python
    python-gobject
)

# AUR Packages
AUR_PACKAGES=(
    apple-fonts                 # SF Pro / New York typography
    apple_cursor                # macOS-White cursor theme
    whitesur-icon-theme         # WhiteSur icon family for live palette matching
    zen-browser-bin             # Zen Browser with quickshell CSS integration
    nautilus-open-any-terminal  # Right click "Open in Ghostty" in Nautilus
    nautilus-admin-gtk4         # Right click "Open as Administrator" in Nautilus
    mpv-modernx                 # Modern OSC interface for MPV
    localsend-bin               # LocalSend cross-platform AirDrop alternative
    vscodium-bin                # VSCodium code editor
    bluetuith                   # Bluetooth TUI
)

check_environment() {
    if [ ! -f /etc/arch-release ]; then
        log_error "This script is designed for Arch Linux. Unsupported distribution."
        exit 1
    fi

    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run install.sh as root or with sudo directly."
        log_error "The script will prompt for sudo when necessary."
        exit 1
    fi

    if ! command -v sudo &>/dev/null; then
        log_error "'sudo' is required but not installed. Please install sudo and grant your user permissions."
        exit 1
    fi
}

install_pacman_packages() {
    log_step "Installing official Arch packages via pacman..."

    # Check for ASUS hardware (ROG, TUF, Zephyrus)
    if [ -d "/sys/devices/platform/asus-nb-wmi" ] || grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        log_info "ASUS hardware detected. Adding asusctl to package list."
        PACMAN_PACKAGES+=("asusctl")
    fi

    sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
    log_success "Official packages installed."
}

bootstrap_aur_helper() {
    log_step "Checking AUR helper..."
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
        log_info "Using existing AUR helper: yay"
        return 0
    fi

    if command -v paru &>/dev/null; then
        AUR_HELPER="paru"
        log_info "Using existing AUR helper: paru"
        return 0
    fi

    log_info "No AUR helper detected. Bootstrapping yay-bin..."
    local tmp_dir
    tmp_dir=$(mktemp -d)
    git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"
    (
        cd "$tmp_dir/yay-bin"
        makepkg -si --noconfirm
    )
    rm -rf "$tmp_dir"
    AUR_HELPER="yay"
    log_success "yay-bin installed successfully."
}

install_aur_packages() {
    log_step "Installing AUR packages..."
    for pkg in "${AUR_PACKAGES[@]}"; do
        log_info "Installing AUR package: $pkg"
        "$AUR_HELPER" -S --needed --noconfirm "$pkg" || log_warn "Warning: Failed to install AUR package '$pkg', continuing..."
    done
    log_success "AUR package installation completed."
}

configure_services() {
    log_step "Configuring essential systemd services..."
    local services=("NetworkManager.service" "bluetooth.service")

    if [ -d "/sys/devices/platform/asus-nb-wmi" ] || grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        services+=("asusd.service")
    fi

    for svc in "${services[@]}"; do
        if systemctl list-unit-files "$svc" &>/dev/null; then
            log_info "Enabling and starting $svc..."
            sudo systemctl enable --now "$svc" || log_warn "Could not enable $svc"
        fi
    done
    log_success "System services configured."
}

configure_gtk_and_desktop() {
    log_step "Configuring GTK, cursor, fonts, and desktop defaults..."

    local gtk3_dir="$CONFIG_DIR/gtk-3.0"
    local gtk4_dir="$CONFIG_DIR/gtk-4.0"
    local icons_default="$HOME/.icons/default"

    mkdir -p "$gtk3_dir" "$gtk4_dir" "$icons_default"

    # GTK 3.0 configuration
    cat > "$gtk3_dir/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=WhiteSur-dark
gtk-font-name=SF Pro Bold 11 @opsz=17,wght=700
gtk-cursor-theme-name=macOS-White
gtk-cursor-theme-size=16
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-toolbar-icon-size=GTK_ICON_SIZE_LARGE_TOOLBAR
gtk-button-images=0
gtk-menu-images=0
gtk-enable-event-sounds=1
gtk-enable-input-feedback-sounds=0
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-application-prefer-dark-theme=1
EOF

    # GTK 4.0 configuration
    cat > "$gtk4_dir/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=WhiteSur-dark
gtk-font-name=SF Pro Bold 11 @opsz=17,wght=700
gtk-cursor-theme-name=macOS-White
gtk-cursor-theme-size=16
gtk-application-prefer-dark-theme=1
EOF

    # X11 / XWayland cursor default fallback
    cat > "$icons_default/index.theme" << 'EOF'
[Icon Theme]
Inherits=macOS-White
EOF

    # User directories (Downloads, Documents, Pictures, etc.)
    if command -v xdg-user-dirs-update &>/dev/null; then
        xdg-user-dirs-update || true
    fi

    # GSettings interface & nautilus preferences
    if command -v gsettings &>/dev/null; then
        # Appearance, Cursor & Fonts
        gsettings set org.gnome.desktop.interface cursor-theme 'macOS-White' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 16 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name 'SF Pro Bold 11 @opsz=17,wght=700' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface document-font-name 'SF Pro weight=860 12 @opsz=17,wght=860' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font Bold 11' 2>/dev/null || true

        # Nautilus preferences
        gsettings set org.gnome.nautilus.preferences show-create-link true 2>/dev/null || true
        gsettings set org.gnome.nautilus.preferences show-delete-permanently true 2>/dev/null || true

        # Nautilus open any terminal -> Ghostty
        gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal 'ghostty' 2>/dev/null || true
    fi

    log_success "GTK, cursor, fonts, and desktop defaults configured."
}

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

setup_symlinks() {
    log_step "Linking configurations into $CONFIG_DIR..."
    link_component "quickshell"
    link_component "hypr"
    link_component "ghostty"

    log_info "Ensuring helper scripts are executable..."
    chmod +x "$REPO_DIR/quickshell/start.sh"
    chmod +x "$REPO_DIR/quickshell/scripts/sync-apps.py"
    chmod +x "$REPO_DIR/quickshell/scripts/scan-wallpapers.sh"
    log_success "Symlinks and permissions ready."
}

setup_user_directories() {
    log_step "Setting up user directories..."
    mkdir -p "$HOME/Pictures/Wallpapers"
    log_info "Wallpaper directory ready at: $HOME/Pictures/Wallpapers"
}

sync_themes() {
    log_step "Compiling and synchronizing themes..."
    if command -v python3 &>/dev/null; then
        python3 "$REPO_DIR/quickshell/scripts/sync-apps.py" || log_warn "sync-apps encountered a non-fatal notice."
    fi
}

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  -y, --yes, --all       Run full automated installation without prompting (packages, AUR, configs, theming)
  --symlinks-only        Only link configurations into ~/.config without installing system packages
  -h, --help             Show this help message
EOF
}

main() {
    echo -e "${BOLD}================================================================${RESET}"
    echo -e "${BOLD}       myshell - Complete Desktop System Installer              ${RESET}"
    echo -e "${BOLD}================================================================${RESET}"

    check_environment

    local mode="ask"
    for arg in "$@"; do
        case "$arg" in
            -y|--yes|--all)
                mode="full"
                ;;
            --symlinks-only)
                mode="symlinks"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $arg"
                show_help
                exit 1
                ;;
        esac
    done

    if [ "$mode" = "ask" ]; then
        echo ""
        echo "This script will perform a complete end-to-end installation:"
        echo "  1. Install all official Arch Linux packages (Hyprland, Quickshell, Ghostty, Nautilus, GNOME apps, Pipewire, etc.)"
        echo "  2. Bootstrap yay (if needed) & install AUR packages (apple-fonts, apple_cursor, whitesur, nautilus-admin, zen-browser, etc.)"
        echo "  3. Enable system services (NetworkManager, bluetooth, asusd if ASUS)"
        echo "  4. Configure GTK4/3 dark theme, macOS cursor, and SF Pro typography"
        echo "  5. Configure Nautilus defaults & Ghostty terminal integration"
        echo "  6. Symlink configs into ~/.config (hypr, quickshell, ghostty)"
        echo "  7. Synchronize initial application themes"
        echo ""
        read -rp "Perform full installation? [Y/n]: " choice
        case "${choice:-Y}" in
            [yY][eE][sS]|[yY]|"")
                mode="full"
                ;;
            *)
                log_info "Skipping package installation. Setting up symlinks and theme configs only."
                mode="symlinks"
                ;;
        esac
    fi

    if [ "$mode" = "full" ]; then
        install_pacman_packages
        bootstrap_aur_helper
        install_aur_packages
        configure_services
    fi

    configure_gtk_and_desktop
    setup_symlinks
    setup_user_directories
    sync_themes

    echo ""
    echo -e "${GREEN}${BOLD}================================================================${RESET}"
    echo -e "${GREEN}${BOLD}         Installation & Configuration Completed Successfully!   ${RESET}"
    echo -e "${GREEN}${BOLD}================================================================${RESET}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Add any wallpapers to ${BOLD}~/Pictures/Wallpapers${RESET}"
    echo -e "  2. To start your desktop session, run:"
    echo -e "     ${CYAN}${BOLD}Hyprland${RESET} (or ${CYAN}${BOLD}start-hyprland${RESET})"
    echo ""
    echo -e "Enjoy your new desktop environment!"
}

main "$@"
