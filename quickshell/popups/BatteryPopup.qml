import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

PopupWindow {
    id: root

    property var targetItem: null
    property var barWindow: null

    function getWidgetCenterX() {
        if (!targetItem) return 0;
        try {
            let p = targetItem.mapToItem(null, 0, 0);
            return p.x + (targetItem.width / 2);
        } catch (e) {
            return targetItem.x + (targetItem.width / 2);
        }
    }

    anchor.window: barWindow ? barWindow : (targetItem ? targetItem.Window.window : null)
    anchor.rect.x: Math.round(getWidgetCenterX() - width / 2)
    anchor.rect.y: barWindow ? barWindow.height : Theme.barHeight
    anchor.rect.width: width
    anchor.rect.height: 0
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: Theme.popupMarginTop
    anchor.adjustment: PopupAdjustment.Slide

    color: "transparent"
    readonly property bool shouldBeOpen: Theme.activePopup === "battery"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 300
    implicitHeight: mainCard.implicitHeight

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            closeAnim.stop();
            popupVisible = true;
            anchor.updateAnchor();
            openAnim.restart();
        } else {
            if (popupVisible) {
                openAnim.stop();
                if (Theme.activePopup !== "") {
                    mainCard.opacity = 0.0;
                    popupScale.xScale = 0.96;
                    popupScale.yScale = 0.96;
                    popupVisible = false;
                } else {
                    closeAnim.restart();
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            anchor.updateAnchor();
            getProfileProc.running = true;
            getLimitProc.running = true;
        } else {
            popupVisible = false;
            if (Theme.activePopup === "battery") {
                Theme.closePopup();
            }
        }
    }

    ParallelAnimation {
        id: openAnim

        NumberAnimation {
            target: mainCard
            property: "opacity"
            from: mainCard.opacity
            to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        onFinished: {
            if (!root.shouldBeOpen) {
                root.popupVisible = false;
            }
        }

        NumberAnimation {
            target: mainCard
            property: "opacity"
            from: mainCard.opacity
            to: 0.0
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: popupScale
            property: "xScale"
            from: popupScale.xScale
            to: 0.96
            duration: 120
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: popupScale
            property: "yScale"
            from: popupScale.yScale
            to: 0.96
            duration: 120
            easing.type: Easing.InCubic
        }
    }

    // ==========================================
    // ASUSCTL PROCESSES & STATE
    // ==========================================
    property string activeAsusProfile: "Performance"
    property int chargeLimit: 80

    Process {
        id: getProfileProc
        command: ["asusctl", "profile", "get"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.includes("Active profile:")) {
                    root.activeAsusProfile = line.replace("Active profile:", "").trim();
                }
            }
        }
    }

    Process {
        id: setProfileProc
        onExited: {
            getProfileProc.running = true;
        }
    }

    function setAsusProfile(name) {
        activeAsusProfile = name;
        setProfileProc.command = ["asusctl", "profile", "set", name];
        setProfileProc.running = true;
    }

    Process {
        id: getLimitProc
        command: ["asusctl", "battery", "info"]
        stdout: SplitParser {
            onRead: (line) => {
                let m = line.match(/(\d+)%/);
                if (m && m[1]) {
                    root.chargeLimit = parseInt(m[1]);
                }
            }
        }
    }

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.isPresent
    readonly property bool isPluggedIn: !UPower.onBattery
    readonly property real changeRate: (device && !isNaN(device.changeRate)) ? device.changeRate : 0.0

    readonly property int batteryPercent: {
        if (!device) return 0;
        let p = device.percentage;
        return (p <= 1.0 && p > 0.0) ? Math.round(p * 100) : Math.round(p);
    }

    readonly property bool isCharging: {
        if (!device) return false;
        return device.state === UPowerDeviceState.Charging;
    }

    readonly property bool isFull: {
        if (!device) return false;
        return device.state === UPowerDeviceState.FullyCharged || batteryPercent >= (chargeLimit > 0 ? (chargeLimit - 1) : 98);
    }

    readonly property color stateColor: {
        if (isCharging) return Theme.cyan;
        if (isFull || batteryPercent >= 50) return Theme.green;
        if (batteryPercent >= 20) return Theme.yellow;
        return Theme.red;
    }

    readonly property string stateText: {
        if (!device) return "Unknown";
        if (isFull) return "Protected (Limit)";
        if (isCharging) return "Charging";
        if (device.state === UPowerDeviceState.Discharging) return "Discharging";
        return isPluggedIn ? "AC Bypass" : "Plugged In";
    }

    readonly property string rateString: {
        if (!device) return "-- W";
        if (changeRate > 0.05) return changeRate.toFixed(1) + " W";
        if (isPluggedIn) return "0.0 W";
        return changeRate >= 0 ? (changeRate.toFixed(1) + " W") : "-- W";
    }

    readonly property string rateSubtitle: {
        if (!device) return "Rate";
        if (isCharging && changeRate > 0.05) return "Charge Rate";
        if (isPluggedIn && (isFull || batteryPercent >= (chargeLimit > 0 ? chargeLimit - 1 : 98))) return "AC Bypass";
        if (isPluggedIn) return "AC Power";
        return "Discharge Rate";
    }

    function formatTime(secs) {
        if (!secs || secs <= 0) return "";
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        return (h > 0 ? (h + "h ") : "") + m + "m remaining";
    }

    Rectangle {
        id: mainCard
        width: parent.width
        implicitHeight: contentCol.implicitHeight + 24
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width / 2
            origin.y: 0
            xScale: 0.94
            yScale: 0.90
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // ==========================================
            // HEADER: Battery Title & Status Badge
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: root.isCharging ? "󰂄" : (root.isPluggedIn ? "󰚥" : "󰁹")
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    color: root.stateColor
                }

                Text {
                    text: "BATTERY & POWER"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Status Badge
                Rectangle {
                    implicitWidth: badgeText.implicitWidth + 12
                    implicitHeight: 20
                    color: Theme.bgSurface
                    border.color: root.stateColor
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.stateText
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        color: root.stateColor
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.borderDim
            }

            // ==========================================
            // BATTERY LEVEL METER & CHARGE LIMIT MARKER
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.batteryPercent + "%"
                            renderType: Theme.renderType
                            font.family: Theme.fontDisplay
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: root.stateColor
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                if (root.isCharging && root.device && root.device.timeToFull > 0) {
                                    return root.formatTime(root.device.timeToFull) + (root.changeRate > 0.05 ? (" (" + root.changeRate.toFixed(1) + " W)") : "");
                                }
                                if (root.isPluggedIn) {
                                    if (root.isFull || root.batteryPercent >= (root.chargeLimit > 0 ? root.chargeLimit - 1 : 98)) {
                                        return "0.0 W • AC Bypass (Limit Active)";
                                    }
                                    return "0.0 W • On AC Power";
                                }
                                if (root.device && root.device.timeToEmpty > 0) {
                                    return root.formatTime(root.device.timeToEmpty) + (root.changeRate > 0.05 ? (" (" + root.changeRate.toFixed(1) + " W)") : "");
                                }
                                return root.changeRate > 0.05 ? (root.changeRate.toFixed(1) + " W") : "";
                            }
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackingTight
                            color: Theme.textSecondary
                        }
                    }

                    // Progress Track with true squared corners & Charge Limit indicator
                    Rectangle {
                        id: trackRect
                        Layout.fillWidth: true
                        implicitHeight: 10
                        color: Theme.bgBase
                        border.color: Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        // Filled portion
                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.batteryPercent / 100)))
                            color: root.stateColor
                            radius: Theme.squareRadius
                        }

                        // Charge Limit Indicator Marker Line
                        Rectangle {
                            visible: root.chargeLimit > 0 && root.chargeLimit < 100
                            x: Math.round(parent.width * (root.chargeLimit / 100)) - 1
                            width: 2
                            height: parent.height + 4
                            y: -2
                            color: Theme.cyan
                            z: 2
                        }
                    }
                }
            }

            // ==========================================
            // CHARGE LIMIT STATUS (READ-ONLY)
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                color: Theme.bgSurface
                border.color: Theme.borderDim
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "󰚥"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.cyan
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "CHARGE LIMIT"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: root.chargeLimit > 0 ? (root.chargeLimit + "% threshold active") : "No limit active"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        implicitWidth: limitBadge.implicitWidth + 12
                        implicitHeight: 20
                        color: Theme.bgBase
                        border.color: Theme.cyan
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Text {
                            id: limitBadge
                            anchors.centerIn: parent
                            text: root.chargeLimit > 0 ? (root.chargeLimit + "%") : "100%"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            color: Theme.cyan
                        }
                    }
                }
            }

            // ==========================================
            // ASUSCTL POWER PROFILES
            // ==========================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "󰓅"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        color: Theme.purple
                    }
                    Text {
                        text: "ASUS POWER PROFILE"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.activeAsusProfile
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: {
                            if (root.activeAsusProfile === "Performance") return Theme.magenta;
                            if (root.activeAsusProfile === "Balanced") return Theme.blue;
                            return Theme.green;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Quiet Profile
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        readonly property bool isCurrent: root.activeAsusProfile === "Quiet"
                        color: isCurrent ? Theme.bgSurfaceActive : (qMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                        border.color: isCurrent ? Theme.green : Theme.borderDim
                        border.width: isCurrent ? 2 : Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰌪"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.green
                            }
                            Text {
                                text: "Quiet"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Bold
                                color: parent.parent.isCurrent ? Theme.green : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: qMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setAsusProfile("Quiet")
                        }
                    }

                    // Balanced Profile
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        readonly property bool isCurrent: root.activeAsusProfile === "Balanced"
                        color: isCurrent ? Theme.bgSurfaceActive : (bMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                        border.color: isCurrent ? Theme.blue : Theme.borderDim
                        border.width: isCurrent ? 2 : Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰾆"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.blue
                            }
                            Text {
                                text: "Balanced"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Bold
                                color: parent.parent.isCurrent ? Theme.blue : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: bMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setAsusProfile("Balanced")
                        }
                    }

                    // Performance Profile
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        readonly property bool isCurrent: root.activeAsusProfile === "Performance"
                        color: isCurrent ? Theme.bgSurfaceActive : (pMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                        border.color: isCurrent ? Theme.magenta : Theme.borderDim
                        border.width: isCurrent ? 2 : Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "󰓅"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.magenta
                            }
                            Text {
                                text: "Perf"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Bold
                                color: parent.parent.isCurrent ? Theme.magenta : Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: pMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setAsusProfile("Performance")
                        }
                    }
                }
            }

            // ==========================================
            // TELEMETRY DETAILS GRID
            // ==========================================
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                // Power consumption
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    color: Theme.bgSurface
                    border.color: Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 1
                        Text {
                            text: root.rateSubtitle
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                        Text {
                            text: root.rateString
                            renderType: Theme.renderType
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Bold
                            color: (root.changeRate > 0.05) ? Theme.cyan : (root.isPluggedIn ? Theme.green : Theme.textPrimary)
                        }
                    }
                }

                // Battery Health
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    color: Theme.bgSurface
                    border.color: Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 1
                        Text {
                            text: "Health"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                        }
                        Text {
                            text: (root.device && root.device.healthSupported && root.device.healthPercentage > 0) ? (Math.round(root.device.healthPercentage) + "%") : "Normal"
                            renderType: Theme.renderType
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Bold
                            color: Theme.green
                        }
                    }
                }
            }

            // Device Model Footer
            Text {
                visible: root.device && root.device.model && root.device.model.length > 0
                text: "Device: " + (root.device ? root.device.model : "")
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                color: Theme.textMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
