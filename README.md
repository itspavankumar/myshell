# myshell 🪟✨

A unified, highly responsive desktop environment for Arch Linux powered by **Hyprland** (Lua config), **Quickshell** (QtQuick/QML), **Ghostty**, and **Zen Browser**.

Featuring live unified theme synchronization across Qt, GTK4/Libadwaita, Ghostty, VSCodium, and Zen Browser.

---

## Architecture Overview

All configurations live in this repository and are symlinked into `~/.config`:

```text
myshell/
├── hypr/               # Hyprland Lua configuration & keybindings
│   ├── hyprland.lua    # Main entry point
│   ├── autostart.lua   # Startup daemons (quickshell, awww, polkit)
│   ├── keybinds.lua    # System and window keybindings
│   ├── looknfeel.lua   # Window decorations, blur, borders
│   └── ...
├── quickshell/         # Modular QtQuick desktop shell
│   ├── bar.qml         # Top status bar & dynamic workspace pills
│   ├── launcher.qml    # Spotlight-style fuzzy application launcher
│   ├── clipboard.qml   # Searchable Wayland clipboard manager
│   ├── lock.qml        # PAM-integrated lockscreen
│   ├── osd.qml         # Audio, brightness & ASUS fan profile OSD
│   ├── themes.qml      # Visual theme selector & palette engine
│   ├── wallpaper.qml   # Wallpaper carousel & random login switcher
│   ├── popups/         # Control center, battery, network, bluetooth, clock
│   ├── theme/zen/      # Zen browser custom CSS templates
│   └── scripts/        # sync-apps.py universal theme synchronizer
├── ghostty/            # GPU-accelerated terminal emulator configuration
│   ├── config.ghostty  # Ghostty options
│   └── theme.ghostty   # Dynamically synced terminal palette
├── install.sh          # One-click symlink & dependency installer
└── README.md
```

---

## Quick Setup (Existing System)

If you already have the packages installed:

```bash
# 1. Clone repository
git clone git@github.com:itspavankumar/myshell.git ~/Projects/myshell
cd ~/Projects/myshell

# 2. Run the installer to create symlinks and sync themes
chmod +x install.sh
./install.sh

# 3. Add wallpapers to your wallpaper directory
mkdir -p ~/Pictures/Wallpapers
# Copy any .jpg / .png / .webp / .gif images into ~/Pictures/Wallpapers
```

---

## Fresh Arch Linux Minimal Install Guide

If you are setting up this desktop from a minimal Arch Linux installation:

### 1. Audio, Bluetooth, Network & Drivers
```bash
sudo pacman -S --needed \
    pipewire pipewire-pulse pipewire-alsa wireplumber \
    bluez bluez-utils \
    networkmanager \
    polkit-gnome
```

Enable essential system services:
```bash
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
```

### 2. Core Desktop & Hyprland
```bash
sudo pacman -S --needed \
    hyprland \
    xdg-desktop-portal-hyprland \
    quickshell \
    ghostty \
    awww \
    brightnessctl \
    wl-clipboard \
    cliphist \
    playerctl
```

### 3. ASUS ROG / TUF Hardware Controls (Optional, for ASUS Laptops)
The shell has built-in integration with `asusctl` for fan profiles and ROG system controls:
```bash
sudo pacman -S --needed asusctl
sudo systemctl enable --now asusd.service
```

### 4. AUR Helper & AUR Packages (Fonts & Apps)
Install `yay` (if not already installed):
```bash
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si && cd -
```

Install typography and browser:
```bash
# San Francisco & New York Apple Fonts (Required for shell typography)
yay -S --needed apple-fonts

# Zen Browser (Firefox-based browser with dynamic theme synchronization)
yay -S --needed zen-browser-bin

# Optional: macOS cursor theme
yay -S --needed apple_cursor
```

### 5. Link and Start the Shell
```bash
git clone git@github.com:itspavankumar/myshell.git ~/Projects/myshell
cd ~/Projects/myshell
./install.sh
```

Now launch Hyprland:
```bash
Hyprland
```

---

## Key Features & Controls

### Shortcut Cheat Sheet
| Shortcut | Action |
| :--- | :--- |
| `Super + Return` | Open Ghostty terminal |
| `Super + Space` | Spotlight Application Launcher |
| `Super + V` | Wayland Clipboard History |
| `Super + L` | Lock Screen |
| `Super + Q` | Close Active Window |
| `Super + E` | Open File Manager (Nautilus) |
| `Volume / Brightness Keys` | Trigger Hardware OSD |

### Shell CLI Commands
Use the Quickshell supervisor script for management:
```bash
# Restart the entire shell
~/.config/quickshell/start.sh restart

# Restart an individual component (bar, launcher, osd, clipboard, wallpaper, etc.)
~/.config/quickshell/start.sh restart bar

# Change theme live across all apps (quickshell, GTK, Ghostty, VSCodium, Zen)
~/.config/quickshell/start.sh theme tokyo-night
~/.config/quickshell/start.sh theme solitude
~/.config/quickshell/start.sh theme catppuccin-mocha

# Cycle or set wallpaper via awww daemon
~/.config/quickshell/start.sh wallpaper random
~/.config/quickshell/start.sh wallpaper /path/to/image.png
```

---

## App Theme Synchronization (`sync-apps.py`)
`quickshell/scripts/sync-apps.py` syncs the active palette across your ecosystem:
- **GTK4 / Libadwaita & GTK3**: Custom accent colors, background bases, and sidebar styling (`~/.config/gtk-4.0/gtk.css`).
- **Ghostty**: Terminal palette (`~/.config/ghostty/theme.ghostty`) reloaded via `SIGUSR2`.
- **Zen Browser**: Profile detection, square corner overrides (`zen.theme.border-radius = 0`), and dynamic stylesheet injection.
- **VSCodium**: Theme palette matching.

---

## License
MIT
