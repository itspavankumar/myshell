import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    property bool isHudOpen: false
    property string pendingMode: "region"

    Timer {
        id: delayTimer
        interval: 180
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
        captureProc.command = [scriptPath, mode];
        captureProc.running = true;
    }

    function capture(mode) {
        closeHud();
        root.pendingMode = mode || "region";
        // 180ms delay gives the Wayland compositor time to cleanly unmap the overlay surface
        delayTimer.start();
    }

    function captureRegion() {
        capture("region");
    }

    function captureWindow() {
        capture("window");
    }

    function captureOutput() {
        capture("output");
    }

    function captureDirect() {
        closeHud();
        let scriptPath = (Quickshell.env("HOME") || "") + "/.config/quickshell/scripts/screenshot.sh";
        captureProc.running = false;
        captureProc.command = [scriptPath, "direct"];
        captureProc.running = true;
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

    // ==========================================
    // IPC HANDLER & HYPRLAND SHORTCUTS
    // ==========================================
    IpcHandler {
        target: "screenshot"

        function direct(): void {
            root.captureDirect();
        }

        function capture(mode: string): void {
            root.capture(mode);
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
        name: "screenshot_direct"
        onPressed: root.captureDirect()
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
