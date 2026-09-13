import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    required property var screen
    property var service: null

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot-overlay"
    WlrLayershell.keyboardFocus: (root.service && root.service.captureMode !== "idle")
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    margins {
        top: 0
        bottom: 0
        left: 0
        right: 0
    }

    visible: root.service && (root.service.captureMode === "region" || root.service.captureMode === "window")

    // Region drag tracking state
    property bool isDragging: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real dragCurrentX: 0
    property real dragCurrentY: 0

    // Cursor crosshair guide position
    property real cursorX: -100
    property real cursorY: -100

    // Window hover tracking state
    property var hoveredWindow: null

    // Format human-friendly window display name
    function formatWindowName(win) {
        if (!win) return "";
        let c = win.className || "";
        if (c.includes(".")) {
            let parts = c.split(".");
            c = parts[parts.length - 1];
        }
        let lower = c.toLowerCase();
        if (lower === "code-oss" || lower === "codium") c = "VSCodium";
        else if (lower === "zen" || lower === "zen-alpha") c = "Zen Browser";
        else if (lower === "ghostty") c = "Ghostty";
        else if (lower === "org.gnome.nautilus" || lower === "nautilus") c = "Files";
        else if (c.length > 0) {
            c = c.charAt(0).toUpperCase() + c.slice(1);
        }

        let t = win.title ? win.title.trim() : "";
        if (t.length > 0 && t !== win.className && !t.startsWith("org.") && !t.startsWith("com.")) {
            if (t.length > 30) t = t.substring(0, 27) + "...";
            return c ? (c + "  —  " + t) : t;
        }
        return c || "Window";
    }

    // Window corner rounding matching Hyprland windowrules.lua (floating = 10px, tiled = 0px)
    function getWindowRadius(win) {
        if (!win) return 0;
        if (win.className === "ONLYOFFICE") return 0;
        if (win.floating) return 10;
        return 0;
    }

    // Computed selection rectangle in local screen coordinates
    readonly property var activeSel: {
        if (!root.service || root.service.captureMode === "idle") return null;

        // 1. User is dragging a custom region
        let dragW = Math.abs(root.dragCurrentX - root.dragStartX);
        let dragH = Math.abs(root.dragCurrentY - root.dragStartY);
        if (root.isDragging && (dragW >= 8 || dragH >= 8)) {
            let x = Math.min(root.dragStartX, root.dragCurrentX);
            let y = Math.min(root.dragStartY, root.dragCurrentY);
            return {
                x: x,
                y: y,
                w: dragW,
                h: dragH,
                title: "",
                className: "",
                displayName: "",
                isWindow: false,
                floating: false,
                radius: 0
            };
        }

        // 2. User is hovering a window in window mode
        if (root.service.captureMode === "window" && root.hoveredWindow) {
            let sx = root.screen.x;
            let sy = root.screen.y;
            let lx = root.hoveredWindow.x - sx;
            let ly = root.hoveredWindow.y - sy;
            return {
                x: lx,
                y: ly,
                w: root.hoveredWindow.w,
                h: root.hoveredWindow.h,
                title: root.hoveredWindow.title || "",
                className: root.hoveredWindow.className || "",
                displayName: root.formatWindowName(root.hoveredWindow),
                isWindow: true,
                floating: !!root.hoveredWindow.floating,
                radius: root.getWindowRadius(root.hoveredWindow)
            };
        }

        return null;
    }

    onVisibleChanged: {
        if (visible) {
            frozenView.captureFrame();
            root.isDragging = false;
            root.dragStartX = 0;
            root.dragStartY = 0;
            root.dragCurrentX = 0;
            root.dragCurrentY = 0;
            root.hoveredWindow = null;
            root.cursorX = -100;
            root.cursorY = -100;
            keyScope.forceActiveFocus();
        }
    }

    // --------------------------------------------------------------------------
    // Frozen Screen Buffer & Shader Crop Pipeline
    // --------------------------------------------------------------------------
    Item {
        id: sceneContainer
        anchors.fill: parent

        ScreencopyView {
            id: frozenView
            anchors.fill: parent
            captureSource: root.screen
            live: false
            paintCursor: false
        }
    }

    // Crop item sampled by Qt Quick grabToImage
    Item {
        id: exportClip
        clip: true
        visible: false
        property real cropX: 0
        property real cropY: 0
        property real cropRadius: 0
        width: 100
        height: 100

        layer.enabled: exportClip.cropRadius > 0
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: exportClip.width
                height: exportClip.height
                radius: exportClip.cropRadius
                antialiasing: true
            }
        }

        ShaderEffectSource {
            id: exportSrc
            sourceItem: sceneContainer
            width: root.width
            height: root.height
            x: -exportClip.cropX
            y: -exportClip.cropY
            live: false
            recursive: false
        }
    }

    function saveCrop(cropX, cropY, cropW, cropH, cropRadius, openMarkup) {
        if (cropW < 6 || cropH < 6) {
            if (root.service) root.service.cancelCapture();
            return;
        }

        // Clamp to screen boundaries
        let finalX = Math.max(0, Math.min(root.width - 2, cropX));
        let finalY = Math.max(0, Math.min(root.height - 2, cropY));
        let finalW = Math.max(1, Math.min(root.width - finalX, cropW));
        let finalH = Math.max(1, Math.min(root.height - finalY, cropH));

        exportClip.cropX = finalX;
        exportClip.cropY = finalY;
        exportClip.width = finalW;
        exportClip.height = finalH;
        exportClip.cropRadius = (cropRadius !== undefined && cropRadius > 0) ? cropRadius : 0;
        exportSrc.x = -finalX;
        exportSrc.y = -finalY;
        exportSrc.scheduleUpdate();

        if (!root.service) return;
        let targetFile = root.service.generateTargetPath();

        exportClip.grabToImage(function(result) {
            if (!result) {
                console.error("ScreenshotOverlay: grabToImage returned null");
                if (root.service) root.service.cancelCapture();
                return;
            }
            let ok = false;
            try {
                ok = result.saveToFile(targetFile);
            } catch (e) {
                console.error("ScreenshotOverlay: saveToFile exception:", e);
            }
            if (ok) {
                if (root.service) root.service.onCaptureFinished(targetFile, openMarkup);
            } else {
                console.error("ScreenshotOverlay: Failed to save to file:", targetFile);
                if (root.service) root.service.cancelCapture();
            }
        });
    }

    // --------------------------------------------------------------------------
    // Dimmed Scrim with Window/Region Cutout
    // --------------------------------------------------------------------------
    readonly property color scrimColor: "#70000000"

    // Full screen dim when nothing is selected yet
    Rectangle {
        anchors.fill: parent
        color: root.scrimColor
        visible: root.activeSel === null
    }

    // 4-Quadrant Cutout when a selection is active (keeps interior bright & untouched)
    Item {
        anchors.fill: parent
        visible: root.activeSel !== null

        // Top Dim Rect
        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: root.activeSel ? Math.max(0, root.activeSel.y) : 0
            color: root.scrimColor
        }

        // Bottom Dim Rect
        Rectangle {
            x: 0
            y: root.activeSel ? root.activeSel.y + root.activeSel.h : 0
            width: parent.width
            height: root.activeSel ? Math.max(0, parent.height - (root.activeSel.y + root.activeSel.h)) : 0
            color: root.scrimColor
        }

        // Left Dim Rect
        Rectangle {
            x: 0
            y: root.activeSel ? root.activeSel.y : 0
            width: root.activeSel ? Math.max(0, root.activeSel.x) : 0
            height: root.activeSel ? root.activeSel.h : 0
            color: root.scrimColor
        }

        // Right Dim Rect
        Rectangle {
            x: root.activeSel ? root.activeSel.x + root.activeSel.w : 0
            y: root.activeSel ? root.activeSel.y : 0
            width: root.activeSel ? Math.max(0, parent.width - (root.activeSel.x + root.activeSel.w)) : 0
            height: root.activeSel ? root.activeSel.h : 0
            color: root.scrimColor
        }
    }

    // --------------------------------------------------------------------------
    // Crosshair Guide Lines (Region Mode Before Drag)
    // --------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        visible: root.service && root.service.captureMode === "region" && !root.isDragging && root.cursorX >= 0

        Rectangle {
            x: 0
            y: root.cursorY
            width: parent.width
            height: 1
            color: "#40ffffff"
        }

        Rectangle {
            x: root.cursorX
            y: 0
            width: 1
            height: parent.height
            color: "#40ffffff"
        }
    }

    // --------------------------------------------------------------------------
    // Active Selection Bounding Box & Highlight
    // --------------------------------------------------------------------------
    Rectangle {
        id: selBox
        visible: root.activeSel !== null && root.activeSel.w > 0 && root.activeSel.h > 0
        x: root.activeSel ? root.activeSel.x : 0
        y: root.activeSel ? root.activeSel.y : 0
        width: root.activeSel ? root.activeSel.w : 0
        height: root.activeSel ? root.activeSel.h : 0
        color: (root.activeSel && root.activeSel.isWindow) ? "#15bb9af7" : "#127aa2f7"
        border.color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
        border.width: 2
        radius: (root.activeSel && root.activeSel.isWindow) ? root.activeSel.radius : 0

        Behavior on x { enabled: !root.isDragging; NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on y { enabled: !root.isDragging; NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on width { enabled: !root.isDragging; NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on height { enabled: !root.isDragging; NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on radius { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }

    // --------------------------------------------------------------------------
    // Floating Info Badge (Clean, Minimal, Theme-Consistent)
    // --------------------------------------------------------------------------
    Rectangle {
        id: infoBadge
        visible: root.activeSel !== null && root.activeSel.w > 20 && root.activeSel.h > 20
        radius: Theme.squareRadius
        color: Theme.bgGlass
        border.color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
        border.width: Theme.borderWidth
        implicitHeight: 30
        implicitWidth: badgeRow.implicitWidth + 24
        width: implicitWidth
        height: implicitHeight

        // Placement logic: Floats centered above the window; if near top edge, flips below
        x: root.activeSel
            ? Math.max(12, Math.min(root.width - width - 12, root.activeSel.x + (root.activeSel.w - width) / 2))
            : 0
        y: {
            if (!root.activeSel) return 0;
            // Prefer placing above window
            let topPos = root.activeSel.y - height - 8;
            if (topPos >= 36) {
                return topPos;
            }
            // If near top edge, place below window (above bottom instructions pill)
            let bottomPos = root.activeSel.y + root.activeSel.h + 8;
            if (bottomPos + height <= root.height - 75) {
                return bottomPos;
            }
            // Fallback inside window near top
            return root.activeSel.y + 10;
        }

        RowLayout {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: (root.activeSel && root.activeSel.isWindow) ? "󰖲" : "󰩬"
                renderType: Theme.renderType
                font.family: Theme.fontIcon
                font.pixelSize: 13
                color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
            }

            Text {
                visible: root.activeSel && root.activeSel.isWindow && root.activeSel.displayName !== ""
                text: root.activeSel ? root.activeSel.displayName : ""
                renderType: Theme.renderType
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontSubhead
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }

            Rectangle {
                visible: root.activeSel && root.activeSel.isWindow && root.activeSel.displayName !== ""
                width: 1
                height: 12
                color: Theme.borderDim
            }

            Text {
                text: root.activeSel ? (Math.round(root.activeSel.w) + " × " + Math.round(root.activeSel.h) + " px") : ""
                renderType: Theme.renderType
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Medium
                color: Theme.textSecondary
            }
        }
    }

    // --------------------------------------------------------------------------
    // Bottom Instructions Pill (Consistent with Screenshot HUD)
    // --------------------------------------------------------------------------
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        implicitHeight: 36
        implicitWidth: hintRow.implicitWidth + 28
        width: implicitWidth
        height: implicitHeight
        radius: Theme.squareRadius
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth

        RowLayout {
            id: hintRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: (root.service && root.service.captureMode === "window") ? "󰖲" : "󰩬"
                renderType: Theme.renderType
                font.family: Theme.fontIcon
                font.pixelSize: 14
                color: (root.service && root.service.captureMode === "window") ? Theme.purple : Theme.cyan
            }

            Text {
                text: (root.service && root.service.captureMode === "window")
                    ? "Click window to capture  •  Drag for custom area  •  Esc to cancel"
                    : "Drag to select capture area  •  Esc to cancel"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
        }
    }

    // --------------------------------------------------------------------------
    // Mouse Interaction (Click Window OR Drag Region)
    // --------------------------------------------------------------------------
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: (root.service && root.service.captureMode === "window" && root.hoveredWindow)
            ? Qt.PointingHandCursor
            : Qt.CrossCursor

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.service) root.service.cancelCapture();
                return;
            }

            if (mouse.button === Qt.LeftButton && root.service) {
                root.isDragging = true;
                root.dragStartX = mouse.x;
                root.dragStartY = mouse.y;
                root.dragCurrentX = mouse.x;
                root.dragCurrentY = mouse.y;
            }
        }

        onPositionChanged: (mouse) => {
            root.cursorX = mouse.x;
            root.cursorY = mouse.y;

            if (root.isDragging) {
                root.dragCurrentX = mouse.x;
                root.dragCurrentY = mouse.y;
            }

            if (root.service && root.service.captureMode === "window") {
                let gx = mouse.x + root.screen.x;
                let gy = mouse.y + root.screen.y;
                root.hoveredWindow = root.service.hitTestWindow(gx, gy);
            }
        }

        onReleased: (mouse) => {
            if (!root.service) return;

            let w = Math.abs(root.dragCurrentX - root.dragStartX);
            let h = Math.abs(root.dragCurrentY - root.dragStartY);
            let x = Math.min(root.dragStartX, root.dragCurrentX);
            let y = Math.min(root.dragStartY, root.dragCurrentY);
            root.isDragging = false;

            // 1. User dragged a custom area (w >= 12 && h >= 12)
            if (w >= 12 && h >= 12) {
                root.saveCrop(x, y, w, h, 0, root.service.openMarkupOnFinish);
                return;
            }

            // 2. Single-click on a window in window mode
            if (root.service.captureMode === "window" && root.hoveredWindow) {
                let win = root.hoveredWindow;
                let lx = win.x - root.screen.x;
                let ly = win.y - root.screen.y;
                let r = root.getWindowRadius(win);
                root.saveCrop(lx, ly, win.w, win.h, r, root.service.openMarkupOnFinish);
                return;
            }

            // 3. Clicked empty area in region mode -> cancel
            if (root.service.captureMode === "region") {
                root.service.cancelCapture();
                return;
            }

            // 4. Clicked empty area in window mode -> cancel
            if (root.service.captureMode === "window" && !root.hoveredWindow) {
                root.service.cancelCapture();
                return;
            }
        }
    }

    // --------------------------------------------------------------------------
    // Keyboard Focus & Escape Handling
    // --------------------------------------------------------------------------
    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root.service) root.service.cancelCapture();
        }
    }

}
