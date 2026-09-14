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
    implicitWidth: 330
    implicitHeight: mainCard.implicitHeight

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            closeAnim.stop();
            popupVisible = true;
            anchor.updateAnchor();
            openAnim.restart();
            getCaffProc.running = true;
            getProfileProc.running = true;
            getLimitProc.running = true;
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
            getCaffProc.running = true;
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
    // CAFFEINATE (KEEP-AWAKE) STATE & CONTROLLER
    // Pure QML Quickshell IPC to LockService
    // ==========================================
    property bool caffeinated: false
    readonly property string lockConfigPath: (Quickshell.env("HOME") || "") + "/.config/quickshell/lock.qml"

    Process {
        id: getCaffProc
        command: ["quickshell", "ipc", "-p", root.lockConfigPath, "call", "lock", "isCaffeinated"]
        stdout: SplitParser {
            onRead: (line) => {
                let trimmed = line.trim();
                if (trimmed === "true") {
                    root.caffeinated = true;
                } else if (trimmed === "false") {
                    root.caffeinated = false;
                }
            }
        }
    }

    Process {
        id: setCaffProc
        onExited: {
            getCaffProc.running = false;
            getCaffProc.running = true;
        }
    }

    function toggleCaffeinate() {
        let targetState = !root.caffeinated;
        root.caffeinated = targetState;
        setCaffProc.command = ["quickshell", "ipc", "-p", root.lockConfigPath, "call", "lock", "setCaffeinated", targetState ? "true" : "false"];
        setCaffProc.running = false;
        setCaffProc.running = true;
    }

    Timer {
        id: caffPollTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            if (!getCaffProc.running && !setCaffProc.running) {
                getCaffProc.running = true;
            }
        }
    }

    Component.onCompleted: {
        getCaffProc.running = true;
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
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 10

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
            // BATTERY LEVEL METER & INTEGRATED CHARGE THRESHOLD
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: meterCol.implicitHeight + 20
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    id: meterCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    spacing: 8

                    // Row 1: Percentage, Limit Badge, Power Rate
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: root.batteryPercent + "%"
                            renderType: Theme.renderType
                            font.family: Theme.fontDisplay
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: root.stateColor
                        }

                        // Integrated Charge Limit Badge
                        Rectangle {
                            visible: root.chargeLimit > 0 && root.chargeLimit < 100
                            implicitWidth: limitBadgeRow.implicitWidth + 10
                            implicitHeight: 20
                            color: Theme.bgBase
                            border.color: Theme.cyan
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            RowLayout {
                                id: limitBadgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "󰚥"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    color: Theme.cyan
                                }

                                Text {
                                    text: root.chargeLimit + "% Limit"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    font.weight: Font.Bold
                                    color: Theme.cyan
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                if (root.isCharging && root.changeRate > 0.05) {
                                    return "+" + root.changeRate.toFixed(1) + " W";
                                }
                                if (root.isPluggedIn) {
                                    return "AC Power";
                                }
                                if (root.changeRate > 0.05) {
                                    return "-" + root.changeRate.toFixed(1) + " W";
                                }
                                return root.rateString;
                            }
                            renderType: Theme.renderType
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.DemiBold
                            color: root.isCharging ? Theme.cyan : (root.isPluggedIn ? Theme.green : Theme.textSecondary)
                        }
                    }

                    // Row 2: Progress Track with true squared corners & Charge Limit indicator
                    Rectangle {
                        id: trackRect
                        Layout.fillWidth: true
                        implicitHeight: 8
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

                    // Row 3: Subhead: Threshold details & hardware bypass state
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: {
                                if (root.isCharging && root.device && root.device.timeToFull > 0) {
                                    return root.formatTime(root.device.timeToFull);
                                }
                                if (root.isPluggedIn) {
                                    if (root.isFull || root.batteryPercent >= (root.chargeLimit > 0 ? root.chargeLimit - 1 : 98)) {
                                        return "Threshold reached • Battery idle";
                                    }
                                    return "Charging to limit";
                                }
                                if (root.device && root.device.timeToEmpty > 0) {
                                    return root.formatTime(root.device.timeToEmpty);
                                }
                                return "Discharging";
                            }
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: Theme.textMuted
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: root.isPluggedIn && (root.isFull || root.batteryPercent >= (root.chargeLimit > 0 ? root.chargeLimit - 1 : 98))
                            text: "Battery Bypassed"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: Theme.green
                        }
                    }
                }
            }

            // ==========================================
            // CAFFEINATE (KEEP-AWAKE) TOGGLE CARD
            // ==========================================
            Rectangle {
                id: caffeinateCard
                Layout.fillWidth: true
                implicitHeight: 46
                color: root.caffeinated ? Theme.bgSurfaceActive : (caffMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                border.color: root.caffeinated ? Theme.yellow : (caffMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Coffee Cup Icon
                    Rectangle {
                        width: 28
                        height: 28
                        color: root.caffeinated ? Qt.rgba(Theme.yellow.r, Theme.yellow.g, Theme.yellow.b, 0.15) : Theme.bgBase
                        border.color: root.caffeinated ? Theme.yellow : Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Text {
                            anchors.centerIn: parent
                            text: root.caffeinated ? "󰅶" : "󰅵"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                            color: root.caffeinated ? Theme.yellow : Theme.textMuted
                        }
                    }

                    // Title & Description
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "KEEP AWAKE"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingTight
                            color: root.caffeinated ? Theme.yellow : Theme.textPrimary
                        }

                        Text {
                            text: root.caffeinated ? "Inhibiting auto-lock & sleep" : "Auto-lock & sleep active (5m/10m)"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: root.caffeinated ? Theme.textSecondary : Theme.textMuted
                        }
                    }

                    // Square Switch Toggle
                    Rectangle {
                        width: 40
                        height: 22
                        color: root.caffeinated ? Theme.yellow : Theme.bgBase
                        border.color: root.caffeinated ? Theme.yellow : Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Toggle knob
                        Rectangle {
                            width: 16
                            height: 16
                            y: 3
                            x: root.caffeinated ? 21 : 3
                            color: root.caffeinated ? Theme.bgBase : Theme.textMuted
                            radius: Theme.squareRadius

                            Behavior on x {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                MouseArea {
                    id: caffMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.toggleCaffeinate();
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
