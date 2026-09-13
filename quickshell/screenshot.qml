//@ pragma UseQApplication
import QtQuick
import Quickshell
import "theme"
import "screenshot"

Scope {
    id: root

    ScreenshotService {
        id: screenshotService
    }

    Variants {
        model: Quickshell.screens

        ScreenshotHud {
            required property var modelData
            screen: modelData
            service: screenshotService
        }
    }
}
