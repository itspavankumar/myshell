import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    property bool isHudOpen: false
    property int delaySeconds: 0 // 0, 3, 5

    property string pendingMode: "region"

    Timer {
        id: delayTimer
        interval: Math.max(100, root.delaySeconds * 1000)
        repeat: false
        onTriggered: {
            runCapture(root.pendingMode);
        }
    }

    Process {
        id: captureProc
    }

    function runCapture(mode) {
        let scriptPath = (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/screenshot.sh";
        captureProc.running = false;
        captureProc.command = [scriptPath, mode, "0"];
        captureProc.running = true;
    }

    function capture(mode, delay) {
        closeHud();
        let d = (typeof delay === "number") ? delay : root.delaySeconds;
        root.pendingMode = mode || "region";

        if (d > 0) {
            delayTimer.interval = d * 1000;
            delayTimer.start();
        } else {
            // Slight 120ms yield to ensure HUD window is completely unmapped before grim snaps the screen
            delayTimer.interval = 120;
            delayTimer.start();
        }
    }

    function captureRegion() {
        capture("region", 0);
    }

    function captureWindow() {
        capture("window", 0);
    }

    function captureOutput() {
        capture("output", 0);
    }

    function openHud() {
        Theme.closePopup();
        isHudOpen = true;
    }

    function closeHud() {
        isHudOpen = false;
    }

    function toggleHud() {
        if (isHudOpen) {
            closeHud();
        } else {
            openHud();
        }
    }

    function cycleDelay() {
        if (delaySeconds === 0) delaySeconds = 3;
        else if (delaySeconds === 3) delaySeconds = 5;
        else delaySeconds = 0;
    }

    // ==========================================
    // IPC HANDLER & HYPRLAND SHORTCUTS
    // ==========================================
    IpcHandler {
        target: "screenshot"

        function capture(mode: string): void {
            root.capture(mode, 0);
        }

        function region(): void {
            root.captureRegion();
        }

        function window(): void {
            root.captureWindow();
        }

        function output(): void {
            root.captureOutput();
        }

        function toggle(): void {
            root.toggleHud();
        }

        function close(): void {
            root.closeHud();
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_region"
        onPressed: root.captureRegion()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_window"
        onPressed: root.captureWindow()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_output"
        onPressed: root.captureOutput()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_toggle"
        onPressed: root.toggleHud()
    }
}
