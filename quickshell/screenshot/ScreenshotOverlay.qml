import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    required property var screen
    property var service: null

    color: "transparent"
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

    // Computed selection rectangle in local screen coordinates
    readonly property var activeSel: {
        if (!root.service || root.service.captureMode === "idle") return null;

        // 1. User is dragging a custom region (supported in both region and window modes)
        let dragW = Math.abs(root.dragCurrentX - root.dragStartX);
        let dragH = Math.abs(root.dragCurrentY - root.dragStartY);
        if (root.isDragging && (dragW >= 10 || dragH >= 10)) {
            let x = Math.min(root.dragStartX, root.dragCurrentX);
            let y = Math.min(root.dragStartY, root.dragCurrentY);
            return { x: x, y: y, w: dragW, h: dragH, title: "", className: "", isWindow: false };
        }

        // 2. User is hovering a window in window mode
        if (root.service.captureMode === "window") {
            if (!root.hoveredWindow) return null;
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
                isWindow: true
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
        width: 100
        height: 100

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

    function saveCrop(cropX, cropY, cropW, cropH, openMarkup) {
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
    readonly property color scrimColor: "#75000000"

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
    // Detectable Window Cards Preview (Window Mode Only)
    // --------------------------------------------------------------------------
    Repeater {
        model: (root.service && root.service.captureMode === "window") ? root.service.currentWindows : []
        delegate: Item {
            id: winCard
            required property var modelData

            property real lx: modelData.x - root.screen.x
            property real ly: modelData.y - root.screen.y
            property bool isHovered: root.hoveredWindow === modelData

            x: lx
            y: ly
            width: modelData.w
            height: modelData.h
            visible: (lx + modelData.w > 0 && lx < root.width && ly + modelData.h > 0 && ly < root.height)

            // Window border preview
            Rectangle {
                anchors.fill: parent
                color: isHovered ? "#22bb9af7" : "transparent"
                border.color: isHovered ? Theme.purple : "#55bb9af7"
                border.width: isHovered ? 2 : 1
                radius: 4

                Behavior on color { ColorAnimation { duration: 80 } }
                Behavior on border.color { ColorAnimation { duration: 80 } }
            }

            // Window corner pill tag
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 6
                implicitHeight: 22
                implicitWidth: winTagRow.implicitWidth + 12
                color: Theme.bgBase
                opacity: isHovered ? 0.95 : 0.75
                radius: 3
                border.color: isHovered ? Theme.purple : Theme.borderDim
                border.width: 1

                RowLayout {
                    id: winTagRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: "󰖲"
                        font.family: Theme.fontIcon
                        font.pixelSize: 11
                        color: winCard.isHovered ? Theme.purple : Theme.textMuted
                        renderType: Theme.renderType
                    }

                    Text {
                        text: winCard.modelData.className
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: winCard.isHovered ? Font.Bold : Font.DemiBold
                        color: winCard.isHovered ? Theme.purple : Theme.textSecondary
                        renderType: Theme.renderType
                    }
                }
            }
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
            color: "#50ffffff"
        }

        Rectangle {
            x: root.cursorX
            y: 0
            width: 1
            height: parent.height
            color: "#50ffffff"
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
        color: (root.activeSel && root.activeSel.isWindow) ? "#20bb9af7" : "#127aa2f7"
        border.color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
        border.width: 2
        radius: (root.activeSel && root.activeSel.isWindow) ? 6 : 0

        Behavior on color { ColorAnimation { duration: 80 } }
        Behavior on border.color { ColorAnimation { duration: 80 } }
    }

    // --------------------------------------------------------------------------
    // Floating Dimensional / Info Badge
    // --------------------------------------------------------------------------
    Rectangle {
        id: infoBadge
        visible: root.activeSel !== null && root.activeSel.w > 20 && root.activeSel.h > 20
        radius: 4
        color: Theme.bgBase
        border.color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
        border.width: 1
        implicitHeight: badgeRow.implicitHeight + 8
        implicitWidth: badgeRow.implicitWidth + 14

        // Placement logic: Position below selection; if at bottom edge, flip above
        x: root.activeSel
            ? Math.max(8, Math.min(root.width - width - 8, root.activeSel.x + (root.activeSel.w - width) / 2))
            : 0
        y: root.activeSel
            ? ((root.activeSel.y + root.activeSel.h + height + 10 < root.height)
                ? (root.activeSel.y + root.activeSel.h + 8)
                : Math.max(8, root.activeSel.y - height - 8))
            : 0

        RowLayout {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: (root.activeSel && root.activeSel.isWindow) ? "󰖲" : "󰩬"
                renderType: Theme.renderType
                font.family: Theme.fontIcon
                font.pixelSize: 12
                color: (root.activeSel && root.activeSel.isWindow) ? Theme.purple : Theme.cyan
            }

            Text {
                text: {
                    if (!root.activeSel) return "";
                    let dim = Math.round(root.activeSel.w) + " × " + Math.round(root.activeSel.h) + " px";
                    if (root.activeSel.isWindow && root.activeSel.className) {
                        return root.activeSel.className + "  (" + dim + ")";
                    }
                    return dim;
                }
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
        }
    }

    // --------------------------------------------------------------------------
    // Top Instructions Pill
    // --------------------------------------------------------------------------
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        implicitHeight: 32
        implicitWidth: hintRow.implicitWidth + 24
        radius: Theme.squareRadius
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: 1

        RowLayout {
            id: hintRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: (root.service && root.service.captureMode === "window") ? "󰖲" : "󰩬"
                renderType: Theme.renderType
                font.family: Theme.fontIcon
                font.pixelSize: 13
                color: (root.service && root.service.captureMode === "window") ? Theme.purple : Theme.cyan
            }

            Text {
                text: (root.service && root.service.captureMode === "window")
                    ? "Click window or drag custom area • Right-click or Esc to cancel"
                    : "Drag to select capture region • Right-click or Esc to cancel"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Medium
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
                root.saveCrop(x, y, w, h, root.service.openMarkupOnFinish);
                return;
            }

            // 2. Single-click on a window in window mode
            if (root.service.captureMode === "window" && root.hoveredWindow) {
                let lx = root.hoveredWindow.x - root.screen.x;
                let ly = root.hoveredWindow.y - root.screen.y;
                root.saveCrop(lx, ly, root.hoveredWindow.w, root.hoveredWindow.h, root.service.openMarkupOnFinish);
                return;
            }

            // 3. Clicked empty area in region mode -> cancel
            if (root.service.captureMode === "region") {
                root.service.cancelCapture();
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

    // --------------------------------------------------------------------------
    // External Service Connections
    // --------------------------------------------------------------------------
    Connections {
        target: root.service

        function onTriggerOutputCapture(openMarkup) {
            // Capture full monitor
            root.saveCrop(0, 0, root.width, root.height, openMarkup);
        }
    }
}
