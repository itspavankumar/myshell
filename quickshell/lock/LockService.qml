pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../theme"

Scope {
    id: root

    property var wallpaperService: null
    property bool isLocked: false
    property string currentPassword: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property string errorMessage: ""
    property bool capsLockOn: false
    property string avatarUrl: ""

    Process {
        id: avatarCheckProc
        command: ["sh", "-c", "if [ -s \"$HOME/.face\" ]; then echo \"file://$HOME/.face\"; elif [ -s \"$HOME/.face.icon\" ]; then echo \"file://$HOME/.face.icon\"; fi"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let l = line.trim();
                if (l) root.avatarUrl = l;
            }
        }
    }

    // Idle & Caffeinate configuration
    property bool idleEnabled: true
    property bool caffeinated: false
    property int idleLockTimeout: 300   // 5 minutes
    property int idleSleepTimeout: 600  // 10 minutes

    Process {
        id: systemdInhibitProc
        command: ["systemd-inhibit", "--what=idle:sleep", "--why=Quickshell Caffeinate", "sleep", "infinity"]
    }

    function setCaffeinated(enabled) {
        let b = (enabled === true || enabled === "true" || enabled === 1 || enabled === "1");
        root.caffeinated = b;
        if (b) {
            systemdInhibitProc.running = false;
            systemdInhibitProc.running = true;
        } else {
            systemdInhibitProc.running = false;
        }
    }

    function toggleCaffeinate() {
        setCaffeinated(!root.caffeinated);
    }

    signal failed()
    signal lockRequested()
    signal unlockRequested()

    onCurrentPasswordChanged: {
        if (showFailure) {
            showFailure = false;
            errorMessage = "";
        }
    }

    // ==========================================
    // PAM AUTHENTICATION CONTEXT
    // ==========================================
    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentPassword);
            }
        }

        onCompleted: (result) => {
            root.unlockInProgress = false;
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.currentPassword = "";
                root.showFailure = true;
                root.errorMessage = "Incorrect password, please try again";
                root.failed();
            }
        }

        onError: (err) => {
            root.unlockInProgress = false;
            root.showFailure = true;
            root.errorMessage = "Authentication failed (" + PamError.toString(err) + ")";
            root.failed();
        }
    }

    // ==========================================
    // LOCK / UNLOCK CONTROLS
    // ==========================================
    function lock() {
        if (root.isLocked) return;
        root.showFailure = false;
        root.errorMessage = "";
        root.currentPassword = "";
        root.unlockInProgress = false;
        root.isLocked = true;
        checkCapsLock();
    }

    function unlock() {
        root.isLocked = false;
        root.currentPassword = "";
        root.showFailure = false;
        root.errorMessage = "";
        root.unlockInProgress = false;
        if (pam.active) {
            pam.abort();
        }
    }

    function tryUnlock() {
        if (!root.isLocked || root.unlockInProgress) return;
        if (root.currentPassword.length === 0) return;

        root.unlockInProgress = true;
        root.showFailure = false;
        root.errorMessage = "";

        if (pam.active) {
            pam.abort();
        }
        pam.start();
    }

    // Helper process for running background commands
    Process {
        id: execProc
    }

    function runCmd(args) {
        execProc.command = args;
        execProc.running = true;
    }

    // ==========================================
    // CAPS LOCK MONITORING
    // ==========================================
    Process {
        id: capslockProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock*/brightness 2>/dev/null | head -n 1"]
        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                root.capsLockOn = (line === "1" || line === "255");
            }
        }
    }

    function checkCapsLock() {
        capslockProc.running = true;
    }

    Timer {
        interval: 800
        running: root.isLocked
        repeat: true
        onTriggered: root.checkCapsLock()
    }

    // ==========================================
    // IDLE DETECTION & DPMS CONTROL
    // ==========================================
    // Check if media is currently actively playing to inhibit idle
    readonly property bool hasActiveMedia: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) {
                return true;
            }
        }
        return false;
    }

    // 1. Idle Lock Monitor (e.g. 5 minutes)
    IdleMonitor {
        id: idleLockMonitor
        enabled: root.idleEnabled && !root.caffeinated && !root.hasActiveMedia
        timeout: root.idleLockTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle && !root.isLocked && root.idleEnabled && !root.caffeinated && !root.hasActiveMedia) {
                root.lock();
            }
        }
    }

    // 2. Idle Display Sleep (DPMS) Monitor (e.g. 10 minutes)
    IdleMonitor {
        id: idleSleepMonitor
        enabled: root.idleEnabled && !root.caffeinated && !root.hasActiveMedia
        timeout: root.idleSleepTimeout
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle && root.idleEnabled && !root.caffeinated && !root.hasActiveMedia) {
                root.runCmd(["hyprctl", "dispatch", "dpms", "off"]);
            } else if (!isIdle) {
                root.runCmd(["hyprctl", "dispatch", "dpms", "on"]);
            }
        }
    }

    // ==========================================
    // SYSTEMD SLEEP & LOGIND MONITORING
    // ==========================================
    Process {
        id: dbusSleepMonitor
        command: ["gdbus", "monitor", "--system", "-d", "org.freedesktop.login1"]
        running: true

        stdout: SplitParser {
            onRead: (line) => {
                if (!line) return;
                // Detect suspend / sleep preparation
                if (line.includes("PrepareForSleep (true,")) {
                    root.lock();
                }
                // Detect loginctl lock-session
                else if (line.includes("Session.Lock ()")) {
                    root.lock();
                }
                // Detect loginctl unlock-session
                else if (line.includes("Session.Unlock ()")) {
                    root.unlock();
                }
            }
        }

        onExited: {
            // Auto-restart monitor if it ever stops
            restartDbusTimer.restart();
        }
    }

    Timer {
        id: restartDbusTimer
        interval: 2000
        repeat: false
        onTriggered: {
            dbusSleepMonitor.running = true;
        }
    }

    // ==========================================
    // HYPRLAND GLOBAL SHORTCUTS
    // ==========================================
    GlobalShortcut {
        appid: "quickshell"
        name: "lock"
        onPressed: root.lock()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "session_lock"
        onPressed: root.lock()
    }

    // ==========================================
    // QUICKSHELL IPC HANDLER
    // (Callable via `qs ipc call lock lock`)
    // ==========================================
    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function unlock(): void {
            root.unlock();
        }

        function toggle(): void {
            if (root.isLocked) {
                root.unlock();
            } else {
                root.lock();
            }
        }

        function isLocked(): bool {
            return root.isLocked;
        }

        function setCaffeinated(enabled: bool): void {
            root.setCaffeinated(enabled);
        }

        function toggleCaffeinate(): void {
            root.toggleCaffeinate();
        }

        function isCaffeinated(): bool {
            return root.caffeinated;
        }
    }

    // ==========================================
    // GLOBAL THEME NOTIFICATIONS
    // ==========================================
    Connections {
        target: Theme
        function onRequestLock() {
            root.lock();
        }
    }
}

