import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../theme"

Scope {
    id: root

    // HUD and Overlay state
    property bool isHudOpen: false
    property string captureMode: "idle" // "idle" | "region" | "window"
    property bool openMarkupOnFinish: true
    property bool pendingWindowCapture: false

    // Active client windows enumerated for window mode
    property var currentWindows: []

    // --------------------------------------------------------------------------
    // File Naming and Target Path Generator
    // --------------------------------------------------------------------------
    function getTimestamp() {
        let d = new Date();
        let pad = (n) => (n < 10 ? "0" + n : "" + n);
        return d.getFullYear() + "-" +
            pad(d.getMonth() + 1) + "-" +
            pad(d.getDate()) + "_" +
            pad(d.getHours()) + "-" +
            pad(d.getMinutes()) + "-" +
            pad(d.getSeconds());
    }

    function generateTargetPath() {
        let shotDir = (Quickshell.env("HOME") || "") + "/Pictures/Screenshots";
        return shotDir + "/Screenshot_" + getTimestamp() + ".png";
    }

    // --------------------------------------------------------------------------
    // Hyprland Active Windows Enumeration
    // --------------------------------------------------------------------------
    Process {
        id: hyprQueryProc
        command: ["bash", "-c", "hyprctl -j monitors 2>/dev/null; echo '---DELIM---'; hyprctl -j clients 2>/dev/null"]
        stdout: StdioCollector { id: hyprQueryOut }
        onExited: (code) => {
            if (code === 0 && hyprQueryOut.text) {
                root.parseHyprlandData(hyprQueryOut.text);
            }
            if (root.pendingWindowCapture) {
                root.pendingWindowCapture = false;
                windowReadyTimer.start();
            }
        }
    }

    Timer {
        id: windowReadyTimer
        interval: 60
        repeat: false
        onTriggered: {
            root.captureMode = "window";
        }
    }

    function refreshWindows(andStartCapture, openMarkup) {
        if (andStartCapture) {
            root.pendingWindowCapture = true;
            root.openMarkupOnFinish = (openMarkup !== false);
        }
        hyprQueryProc.running = false;
        hyprQueryProc.running = true;
    }

    function parseHyprlandData(rawText) {
        let parts = rawText.split("---DELIM---");
        if (parts.length < 2) return;

        let monText = parts[0].trim();
        let cliText = parts[1].trim();

        try {
            let monitors = JSON.parse(monText);
            let activeWs = [];
            for (let i = 0; i < monitors.length; i++) {
                let m = monitors[i];
                if (m.activeWorkspace && m.activeWorkspace.id !== undefined) {
                    activeWs.push(m.activeWorkspace.id);
                }
                if (m.specialWorkspace && m.specialWorkspace.id !== 0 && m.specialWorkspace.id !== undefined) {
                    activeWs.push(m.specialWorkspace.id);
                }
            }

            let clients = JSON.parse(cliText);
            let windows = [];
            for (let i = 0; i < clients.length; i++) {
                let c = clients[i];
                if (!c.mapped || c.hidden) continue;

                let wsId = c.workspace ? c.workspace.id : null;
                let isPinned = !!c.pinned;
                let isVisibleWs = isPinned || (wsId !== null && activeWs.indexOf(wsId) !== -1);
                if (!isVisibleWs) continue;

                let at = c.at || [0, 0];
                let size = c.size || [0, 0];
                if (size[0] <= 10 || size[1] <= 10) continue;

                windows.push({
                    x: at[0],
                    y: at[1],
                    w: size[0],
                    h: size[1],
                    title: c.title || "",
                    className: c.class || c.initialClass || "Window",
                    floating: !!c.floating,
                    pinned: isPinned,
                    focusHistoryID: c.focusHistoryID !== undefined ? c.focusHistoryID : 999
                });
            }

            root.currentWindows = windows;
        } catch (e) {
            console.error("ScreenshotService: Error parsing Hyprland clients:", e);
        }
    }

    function hitTestWindow(gx, gy) {
        let hits = [];
        for (let i = 0; i < root.currentWindows.length; i++) {
            let w = root.currentWindows[i];
            if (gx >= w.x && gx < w.x + w.w && gy >= w.y && gy < w.y + w.h) {
                hits.push(w);
            }
        }
        if (hits.length === 0) return null;

        // Rank candidate windows under cursor:
        // 1. Pinned windows first (always on top)
        // 2. Floating windows next (always on top of tiled windows)
        // 3. Smaller area next (nested / popup / dialog windows beat full-screen parents)
        // 4. Lower focusHistoryID (most recently focused)
        hits.sort((a, b) => {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
            if (a.floating !== b.floating) return a.floating ? -1 : 1;

            let areaA = a.w * a.h;
            let areaB = b.w * b.h;
            if (areaA !== areaB) return areaA - areaB;

            return a.focusHistoryID - b.focusHistoryID;
        });

        return hits[0];
    }

    // --------------------------------------------------------------------------
    // Capture Orchestration & HUD Unmapping Timer
    // --------------------------------------------------------------------------
    Timer {
        id: unmapDelayTimer
        interval: 90
        repeat: false
        property string pendingMode: "region"
        property bool pendingMarkup: true

        onTriggered: {
            root.openMarkupOnFinish = pendingMarkup;
            root.captureMode = pendingMode;
        }
    }

    function openHud() {
        Theme.closePopup();
        root.captureMode = "idle";
        root.pendingWindowCapture = false;
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

    function startRegionCapture(openMarkup) {
        closeHud();
        unmapDelayTimer.pendingMode = "region";
        unmapDelayTimer.pendingMarkup = (openMarkup !== false);
        unmapDelayTimer.start();
    }

    function startWindowCapture(openMarkup) {
        closeHud();
        refreshWindows(true, openMarkup);
    }

    // --------------------------------------------------------------------------
    // Fullscreen Capture (with clean HUD unmapping and Satty markup)
    // --------------------------------------------------------------------------
    Process {
        id: fullscreenSnapProc
        property string targetFile: ""
        property bool openMarkup: true
        onExited: (exitCode) => {
            if (exitCode === 0 && targetFile) {
                root.onCaptureFinished(targetFile, openMarkup);
            }
        }
    }

    Timer {
        id: fullscreenDelayTimer
        interval: 100
        repeat: false
        property bool pendingMarkup: true
        onTriggered: {
            let targetFile = root.generateTargetPath();
            fullscreenSnapProc.targetFile = targetFile;
            fullscreenSnapProc.openMarkup = pendingMarkup;
            fullscreenSnapProc.command = [
                "bash", "-c",
                "mkdir -p \"$(dirname \"$1\")\" && grim \"$1\"",
                "_", targetFile
            ];
            fullscreenSnapProc.running = false;
            fullscreenSnapProc.running = true;
        }
    }

    function captureOutput(openMarkup) {
        closeHud();
        root.captureMode = "idle";
        root.pendingWindowCapture = false;
        fullscreenDelayTimer.pendingMarkup = (openMarkup !== false);
        fullscreenDelayTimer.start();
    }

    function captureRegion() {
        startRegionCapture(true);
    }

    function captureWindow() {
        startWindowCapture(true);
    }

    function cancelCapture() {
        root.captureMode = "idle";
        root.pendingWindowCapture = false;
    }

    // --------------------------------------------------------------------------
    // Direct Instant Capture (Print Key - No HUD, No Satty)
    // --------------------------------------------------------------------------
    Process {
        id: directSnapProc
    }

    function captureDirect() {
        closeHud();
        root.captureMode = "idle";
        root.pendingWindowCapture = false;

        let targetFile = generateTargetPath();
        let fileName = targetFile.split("/").pop();

        let cmd = [
            "bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; " +
            "grim \"$1\" 2>/dev/null || true; " +
            "if [ -s \"$1\" ]; then " +
            "  wl-copy --type image/png < \"$1\" 2>/dev/null || true; " +
            "  notify-send -a 'Screenshot' -i \"$1\" -h string:image-path:\"$1\" 'Screenshot Saved' 'Captured full screen to clipboard & saved to ~/Pictures/Screenshots/'\"$2\" 2>/dev/null || true; " +
            "fi",
            "_", targetFile, fileName
        ];

        directSnapProc.command = cmd;
        directSnapProc.running = false;
        directSnapProc.running = true;
    }

    // --------------------------------------------------------------------------
    // Post-Capture Handler (Clipboard, Notifications, Floating Satty)
    // --------------------------------------------------------------------------
    Process {
        id: postCaptureProc
    }

    function onCaptureFinished(targetFile, openMarkup) {
        root.captureMode = "idle";
        root.pendingWindowCapture = false;

        let fileName = targetFile.split("/").pop();
        let cmd = [
            "bash", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; " +
            "wl-copy --type image/png < \"$1\" 2>/dev/null || true; " +
            "notify-send -a 'Screenshot' -i \"$1\" -h string:image-path:\"$1\" 'Screenshot Saved' 'Captured to clipboard & saved to ~/Pictures/Screenshots/'\"$2\" 2>/dev/null || true; " +
            (openMarkup ? "satty -f \"$1\" --output-filename \"$1\" --early-exit --save-after-copy --copy-command 'wl-copy' --disable-notifications 2>/dev/null || true" : ""),
            "_", targetFile, fileName
        ];

        postCaptureProc.command = cmd;
        postCaptureProc.running = false;
        postCaptureProc.running = true;
    }

    // --------------------------------------------------------------------------
    // IPC Handler (External CLI & Shell Communication)
    // --------------------------------------------------------------------------
    IpcHandler {
        target: "screenshot"

        function direct(): void {
            root.captureDirect();
        }

        function capture(mode: string): void {
            if (mode === "direct") {
                root.captureDirect();
            } else if (mode === "window") {
                root.startWindowCapture(true);
            } else if (mode === "output" || mode === "screen" || mode === "fullscreen") {
                root.captureOutput(true);
            } else {
                root.startRegionCapture(true);
            }
        }

        function region(): void {
            root.startRegionCapture(true);
        }

        function window(): void {
            root.startWindowCapture(true);
        }

        function output(): void {
            root.captureOutput(true);
        }

        function toggle(): void {
            root.toggleHud();
        }

        function close(): void {
            root.closeHud();
        }
    }

    // --------------------------------------------------------------------------
    // Global Shortcuts
    // --------------------------------------------------------------------------
    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_direct"
        onPressed: root.captureDirect()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_region"
        onPressed: root.startRegionCapture(true)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_window"
        onPressed: root.startWindowCapture(true)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_output"
        onPressed: root.captureOutput(true)
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot_toggle"
        onPressed: root.toggleHud()
    }
}
