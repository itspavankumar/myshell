pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property var service
    required property var wallpaperService

    WlSessionLock {
        id: sessionLock
        locked: root.service.isLocked

        onLockStateChanged: {
            if (root.service.isLocked !== locked) {
                root.service.isLocked = locked;
            }
        }

        LockSurface {
            service: root.service
            wallpaperService: root.wallpaperService
        }
    }

    Connections {
        target: root.service
        function onUnlockRequested() {
            sessionLock.unlock();
        }
    }
}

