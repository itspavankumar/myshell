//@ pragma UseQApplication
import QtQuick
import Quickshell
import "theme"
import "wallpaper"

Scope {
    id: root

    WallpaperService {
        id: wallpaperService
    }

    Variants {
        model: Quickshell.screens

        WallpaperSwitcher {
            required property var modelData
            screen: modelData
            service: wallpaperService
        }
    }
}
