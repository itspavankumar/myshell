//@ pragma UseQApplication
import QtQuick
import Quickshell
import "theme"
import "osd"

Scope {
    id: root

    OSDService {
        id: osdService
    }

    Variants {
        model: Quickshell.screens

        OSD {
            required property var modelData
            screen: modelData
            service: osdService
        }
    }
}

