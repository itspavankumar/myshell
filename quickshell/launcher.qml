//@ pragma UseQApplication
import QtQuick
import Quickshell
import "theme"
import "launcher"

Scope {
    id: root

    LauncherService {
        id: launcherService
    }

    Variants {
        model: Quickshell.screens

        Launcher {
            required property var modelData
            screen: modelData
            service: launcherService
        }
    }
}

