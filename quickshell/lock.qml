//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme"
import "wallpaper"
import "lock"

Scope {
    id: root

    WallpaperService {
        id: wallpaperService
    }

    LockService {
        id: lockService
        wallpaperService: wallpaperService
    }

    LockScreen {
        service: lockService
        wallpaperService: wallpaperService
    }
}

