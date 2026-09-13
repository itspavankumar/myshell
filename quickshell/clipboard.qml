//@ pragma UseQApplication
import QtQuick
import Quickshell
import "theme"
import "clipboard"

Scope {
    id: root

    ClipboardService {
        id: clipboardService
    }

    Variants {
        model: Quickshell.screens

        Clipboard {
            required property var modelData
            screen: modelData
            service: clipboardService
        }
    }
}

