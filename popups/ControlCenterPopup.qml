import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
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
    readonly property bool shouldBeOpen: Theme.activePopup === "controlcenter"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 340
    implicitHeight: 600

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: Theme.closePopup()
    }

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
                    currentView = "main";
                } else {
                    closeAnim.restart();
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            anchor.updateAnchor();
            getBrightnessProc.running = true;
            getProfileProc.running = true;
            getLimitProc.running = true;
            getMonitorProc.running = true;
        } else {
            popupVisible = false;
            if (Theme.activePopup === "controlcenter") {
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
                root.currentView = "main";
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
    // BRIGHTNESS SERVICE (brightnessctl)
    // ==========================================
    property int brightnessPercent: 50

    Process {
        id: getBrightnessProc
        command: ["brightnessctl", "-m"]
        stdout: SplitParser {
            onRead: (line) => {
                let parts = line.split(",");
                if (parts.length >= 4) {
                    let p = parseInt(parts[3].replace("%", "").trim());
                    if (!isNaN(p)) {
                        root.brightnessPercent = p;
                    }
                }
            }
        }
    }

    Process {
        id: setBrightnessProc
    }

    function setBrightness(percent) {
        root.brightnessPercent = Math.max(1, Math.min(100, percent));
        setBrightnessProc.command = ["brightnessctl", "-n", "set", root.brightnessPercent + "%"];
        setBrightnessProc.running = true;
    }

    // ==========================================
    // AUDIO SERVICE (Pipewire)
    // ==========================================
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool hasSink: sink !== null && sink.audio !== null
    readonly property real sinkVolume: hasSink ? sink.audio.volume : 0.0
    readonly property bool sinkMuted: hasSink ? sink.audio.muted : false
    readonly property int sinkPercent: Math.round(sinkVolume * 100)

    function toggleSinkMute() {
        if (hasSink) {
            sink.audio.muted = !sink.audio.muted;
        }
    }

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool hasSource: source !== null && source.audio !== null
    readonly property real sourceVolume: hasSource ? source.audio.volume : 0.0
    readonly property bool sourceMuted: hasSource ? source.audio.muted : false
    readonly property int sourcePercent: Math.round(sourceVolume * 100)

    function toggleSourceMute() {
        if (hasSource) {
            source.audio.muted = !source.audio.muted;
        }
    }

    property string currentView: "main"
    readonly property bool soundViewOpen: currentView === "sound"
    readonly property bool batteryViewOpen: currentView === "battery"
    readonly property bool wifiViewOpen: currentView === "wifi"
    readonly property bool bluetoothViewOpen: currentView === "bluetooth"

    // ==========================================
    // DISPLAY & COLOR MANAGEMENT (HDR/SDR & Gamut)
    // ==========================================
    property string displayDynamicRange: "SDR"
    property bool isHdrActive: false
    property string displayGamutStr: "DCI-P3"
    property string displayBitDepth: "10-bit"

    Process {
        id: getMonitorProc
        command: ["hyprctl", "monitors", "-j"]
        property string jsonBuffer: ""
        onRunningChanged: {
            if (running) jsonBuffer = "";
        }
        stdout: SplitParser {
            onRead: (line) => {
                getMonitorProc.jsonBuffer += line;
            }
        }
        onExited: {
            try {
                let monitors = JSON.parse(jsonBuffer);
                if (monitors && monitors.length > 0) {
                    let m = monitors[0];
                    let cm = (m.colorManagementPreset || "").toLowerCase();
                    if (cm === "hdr") {
                        root.isHdrActive = true;
                        root.displayDynamicRange = "HDR";
                        root.displayGamutStr = "BT.2020";
                    } else if (cm === "wide") {
                        root.isHdrActive = false;
                        root.displayDynamicRange = "SDR";
                        root.displayGamutStr = "DCI-P3";
                    } else if (cm === "srgb") {
                        root.isHdrActive = false;
                        root.displayDynamicRange = "SDR";
                        root.displayGamutStr = "sRGB";
                    } else {
                        root.isHdrActive = false;
                        root.displayDynamicRange = "SDR";
                        root.displayGamutStr = cm ? cm.toUpperCase() : "sRGB";
                    }

                    let fmt = m.currentFormat || "";
                    if (fmt.includes("2101010") || fmt.includes("10")) {
                        root.displayBitDepth = "10-bit";
                    } else if (fmt.includes("8888") || fmt.includes("8")) {
                        root.displayBitDepth = "8-bit";
                    } else {
                        root.displayBitDepth = "";
                    }
                }
            } catch (e) {}
        }
    }

    // ==========================================
    // WIFI SERVICE
    // ==========================================
    readonly property bool isWifiEnabled: Networking.wifiEnabled
    readonly property var wifiDev: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            let dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }
    readonly property bool isWifiConnected: wifiDev !== null && wifiDev.connected

    readonly property string wifiSsid: {
        if (!isWifiEnabled) return "Disabled";
        if (isWifiConnected) {
            if (wifiDev && wifiDev.networks && wifiDev.networks.values.length > 0) {
                for (let i = 0; i < wifiDev.networks.values.length; i++) {
                    let net = wifiDev.networks.values[i];
                    if (net && net.connected) {
                        let name = net.name || net.ssid || "";
                        if (name) return "Connected to " + name;
                    }
                }
            }
            return "Connected";
        }
        return "Not Connected";
    }

    // ==========================================
    // BLUETOOTH SERVICE
    // ==========================================
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool hasBt: btAdapter !== null
    readonly property bool isBtEnabled: hasBt && btAdapter.enabled
    readonly property string btStatusText: {
        if (!hasBt || !isBtEnabled) return "Disabled";
        if (Bluetooth.devices && Bluetooth.devices.values.length > 0) {
            for (let i = 0; i < Bluetooth.devices.values.length; i++) {
                let d = Bluetooth.devices.values[i];
                if (d && d.connected) return d.name || "Connected";
            }
        }
        return "Enabled";
    }

    // ==========================================
    // ASUS PROFILE SERVICE
    // ==========================================
    property string activeAsusProfile: "Performance"

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
        id: cycleProfileProc
        command: ["asusctl", "profile", "-n"]
        onExited: getProfileProc.running = true
    }

    // ==========================================
    // POWER & BATTERY SERVICE
    // ==========================================
    Process {
        id: setProfileProc
        onExited: getProfileProc.running = true
    }

    function setAsusProfile(name) {
        activeAsusProfile = name;
        setProfileProc.command = ["asusctl", "profile", "set", name];
        setProfileProc.running = true;
    }

    property int chargeLimit: 80
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

    readonly property var uDev: UPower.displayDevice
    readonly property bool hasBattery: uDev !== null && uDev.isPresent
    readonly property bool isPluggedIn: !UPower.onBattery
    readonly property real changeRate: (uDev && !isNaN(uDev.changeRate)) ? uDev.changeRate : 0.0
    readonly property int batteryPercent: {
        if (!uDev) return 0;
        let p = uDev.percentage;
        return (p <= 1.0 && p > 0.0) ? Math.round(p * 100) : Math.round(p);
    }
    readonly property bool isCharging: {
        if (!uDev) return false;
        return uDev.state === UPowerDeviceState.Charging;
    }
    readonly property bool isFull: {
        if (!uDev) return false;
        return uDev.state === UPowerDeviceState.FullyCharged || batteryPercent >= (chargeLimit > 0 ? (chargeLimit - 1) : 98);
    }
    readonly property color stateColor: {
        if (isCharging) return Theme.cyan;
        if (isFull || batteryPercent >= 50) return Theme.green;
        if (batteryPercent >= 20) return Theme.yellow;
        return Theme.red;
    }
    readonly property string stateText: {
        if (!uDev) return "Unknown";
        if (isFull) return "Protected (Limit)";
        if (isCharging) return "Charging";
        if (uDev.state === UPowerDeviceState.Discharging) return "Discharging";
        return isPluggedIn ? "AC Bypass" : "Plugged In";
    }

    function formatTime(secs) {
        if (!secs || secs <= 0) return "";
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        return (h > 0 ? (h + "h ") : "") + m + "m remaining";
    }

    // ==========================================
    // MEDIA SERVICE
    // ==========================================
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            let p = players[i];
            if (p && p.playbackState === MprisPlaybackState.Playing) return p;
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool isMediaPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing

    // Generic Command Execution Process
    Process {
        id: cmdProc
    }

    function runCmd(args) {
        cmdProc.command = args;
        cmdProc.running = true;
    }

    // ==========================================
    // MAIN POPUP CARD
    // ==========================================
    Rectangle {
        id: mainCard
        width: parent.width
        clip: true

        readonly property real targetHeight: {
            if (root.currentView === "sound") return soundViewCol.implicitHeight + 24;
            if (root.currentView === "battery") return batteryViewCol.implicitHeight + 24;
            if (root.currentView === "wifi") return wifiViewCol.implicitHeight + 24;
            if (root.currentView === "bluetooth") return bluetoothViewCol.implicitHeight + 24;
            return contentCol.implicitHeight + 24;
        }

        height: targetHeight
        implicitHeight: height

        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width / 2
            origin.y: 0
            xScale: 0.96
            yScale: 0.96
        }

        ColumnLayout {
            id: contentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12
            enabled: root.currentView === "main"
            visible: opacity > 0.001
            opacity: root.currentView === "main" ? 1.0 : 0.0

            transform: Translate {
                x: root.currentView === "main" ? 0 : -20
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }
            // ==========================================
            // HEADER: Control Center Title & Power Pill
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰘳"
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    renderType: Theme.renderType
                    color: Theme.cyan
                }

                Text {
                    text: "CONTROL CENTER"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Battery status badge
                Rectangle {
                    visible: root.hasBattery
                    implicitWidth: batBadgeRow.implicitWidth + 14
                    implicitHeight: 24
                    color: batMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: batMouse.containsMouse ? root.stateColor : Theme.borderDim
                    border.width: 1
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        id: batBadgeRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            text: root.isCharging ? "󰂄" : (root.isPluggedIn ? "󰚥" : "󰁹")
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: root.stateColor
                        }

                        Text {
                            text: root.batteryPercent + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Bold
                            renderType: Theme.renderType
                            color: batMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                        }

                        Text {
                            text: "󰅂"
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            renderType: Theme.renderType
                            color: batMouse.containsMouse ? root.stateColor : Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: batMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentView = "battery"
                    }
                }
            }

            // ==========================================
            // QUICK TOGGLES GRID (2 x 2)
            // ==========================================
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                // Wi-Fi Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 48
                    clip: true
                    color: root.isWifiConnected ? Theme.bgSurfaceActive : (wifiMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                    border.color: root.isWifiConnected ? Theme.cyan : (wifiMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 4

                        // Left Clickable Toggle Area
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: root.isWifiConnected ? "󰤨" : (root.isWifiEnabled ? "󰤟" : "󰤭")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    renderType: Theme.renderType
                                    color: root.isWifiConnected ? Theme.cyan : Theme.textMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    spacing: 1

                                    Text {
                                        text: "Wi-Fi"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontHeadline
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: root.wifiSsid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSubhead
                                        font.weight: Font.Medium
                                        font.letterSpacing: Theme.trackingTight
                                        renderType: Theme.renderType
                                        color: root.isWifiConnected ? Theme.cyan : Theme.textMuted
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                    }
                                }
                            }

                            MouseArea {
                                id: wifiMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                            }
                        }

                        // Arrow Button (opens Wi-Fi subview)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 18
                            implicitHeight: 28
                            color: wifiArrowMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            border.color: wifiArrowMouse.containsMouse ? Theme.cyan : Theme.borderDim
                            border.width: 1
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                renderType: Theme.renderType
                                color: wifiArrowMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                            }

                            MouseArea {
                                id: wifiArrowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentView = "wifi";
                                }
                            }
                        }
                    }
                }

                // Bluetooth Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 48
                    clip: true
                    color: (root.hasBt && root.isBtEnabled) ? Theme.bgSurfaceActive : (btMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                    border.color: (root.hasBt && root.isBtEnabled) ? Theme.blue : (btMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 4

                        // Left Clickable Toggle Area
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.fill: parent
                                spacing: 8

                                Text {
                                    text: (root.hasBt && root.isBtEnabled) ? "󰂯" : "󰂲"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    renderType: Theme.renderType
                                    color: (root.hasBt && root.isBtEnabled) ? Theme.blue : Theme.textMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 0
                                    spacing: 1

                                    Text {
                                        text: "Bluetooth"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontHeadline
                                        font.weight: Font.DemiBold
                                        renderType: Theme.renderType
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: root.btStatusText
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSubhead
                                        font.weight: Font.Medium
                                        font.letterSpacing: Theme.trackingTight
                                        renderType: Theme.renderType
                                        color: (root.hasBt && root.isBtEnabled) ? Theme.blue : Theme.textMuted
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 0
                                    }
                                }
                            }

                            MouseArea {
                                id: btMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.hasBt) {
                                        root.btAdapter.enabled = !root.btAdapter.enabled;
                                    }
                                }
                            }
                        }

                        // Arrow Button (opens Bluetooth subview)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 18
                            implicitHeight: 28
                            color: btArrowMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            border.color: btArrowMouse.containsMouse ? Theme.blue : Theme.borderDim
                            border.width: 1
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                renderType: Theme.renderType
                                color: btArrowMouse.containsMouse ? Theme.blue : Theme.textSecondary
                            }

                            MouseArea {
                                id: btArrowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentView = "bluetooth";
                                }
                            }
                        }
                    }
                }

                // Power Profile Tile (asusctl)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 48
                    clip: true
                    color: profileMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: profileMouse.containsMouse ? Theme.borderBright : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: root.activeAsusProfile === "Quiet" ? "󰾅" : (root.activeAsusProfile === "Balanced" ? "󰾆" : "󰓅")
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            renderType: Theme.renderType
                            color: root.activeAsusProfile === "Quiet" ? Theme.cyan : (root.activeAsusProfile === "Balanced" ? Theme.blue : Theme.magenta)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            spacing: 1

                            Text {
                                text: "Profile"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Font.DemiBold
                                renderType: Theme.renderType
                                color: Theme.textPrimary
                            }

                            Text {
                                text: root.activeAsusProfile
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackingTight
                                renderType: Theme.renderType
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }
                        }
                    }

                    MouseArea {
                        id: profileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cycleProfileProc.running = true
                    }
                }

                // Display Information Tile (HDR/SDR & Color Gamut)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    implicitHeight: 48
                    clip: true
                    color: Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 6
                        anchors.bottomMargin: 6
                        spacing: 8

                        Text {
                            text: "󰍹"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            renderType: Theme.renderType
                            color: root.isHdrActive ? Theme.purple : Theme.cyan
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 0
                            spacing: 1

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: "Display"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: Font.DemiBold
                                    renderType: Theme.renderType
                                    color: Theme.textPrimary
                                }

                                // HDR / SDR Dynamic Range Badge
                                Rectangle {
                                    implicitHeight: 16
                                    implicitWidth: hdrBadgeText.implicitWidth + 8
                                    color: root.isHdrActive ? "#2a2238" : Theme.bgBase
                                    border.color: root.isHdrActive ? Theme.purple : Theme.borderDim
                                    border.width: 1
                                    radius: Theme.squareRadius

                                    Text {
                                        id: hdrBadgeText
                                        anchors.centerIn: parent
                                        text: root.displayDynamicRange || "SDR"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.Bold
                                        renderType: Theme.renderType
                                        color: root.isHdrActive ? Theme.purple : Theme.cyan
                                    }
                                }
                            }

                            // Color Gamut & Bit Depth
                            Text {
                                text: (root.displayGamutStr || "sRGB") + (root.displayBitDepth ? " • " + root.displayBitDepth : "")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackingTight
                                renderType: Theme.renderType
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }
                        }
                    }
                }

                // Theme Selection Tile
                Rectangle {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    implicitHeight: 38
                    clip: true
                    color: themeTileMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: themeTileMouse.containsMouse ? Theme.accent : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "󰏘"
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            renderType: Theme.renderType
                            color: Theme.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "Theme"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                                color: Theme.textMuted
                                renderType: Theme.renderType
                            }

                            Text {
                                text: Theme.activePalette.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Font.Bold
                                color: Theme.accent
                                renderType: Theme.renderType
                            }
                        }

                        // Mini swatches preview
                        Row {
                            spacing: 3
                            Layout.alignment: Qt.AlignVCenter
                            Repeater {
                                model: Theme.activePalette.swatches
                                Rectangle {
                                    required property string modelData
                                    width: 10
                                    height: 10
                                    radius: 2
                                    color: modelData
                                    border.color: Theme.borderDim
                                    border.width: 1
                                }
                            }
                        }

                        Text {
                            text: "󰅂"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            renderType: Theme.renderType
                            color: themeTileMouse.containsMouse ? Theme.accent : Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: themeTileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["quickshell", "ipc", "-p", "/home/pavan/.config/quickshell/themes.qml", "call", "themes", "toggle"]);
                        }
                    }
                }
            }

            // ==========================================
            // BRIGHTNESS SLIDER
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: root.brightnessPercent > 70 ? "󰃠" : (root.brightnessPercent > 30 ? "󰃟" : "󰃞")
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            renderType: Theme.renderType
                            color: Theme.yellow
                        }

                        Text {
                            text: "Brightness"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            font.letterSpacing: Theme.trackingNormal
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.brightnessPercent + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.yellow
                        }
                    }

                    // Track & Grab Handle
                    Rectangle {
                        id: brightTrack
                        Layout.fillWidth: true
                        implicitHeight: 12
                        color: Theme.bgBase
                        border.color: Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Rectangle {
                            id: brightFill
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.brightnessPercent / 100.0)))
                            color: Theme.yellow
                            radius: Theme.squareRadius
                        }

                        Rectangle {
                            id: brightThumb
                            width: 10
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, brightFill.width - (width / 2)))
                            color: brightMouse.containsMouse || brightMouse.pressed ? Theme.yellow : Theme.textPrimary
                            border.color: Theme.bgBase
                            border.width: 1
                            radius: Theme.squareRadius
                        }

                        MouseArea {
                            id: brightMouse
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function setVal(mouse) {
                                let ratio = Math.max(0.01, Math.min(1.0, mouse.x / brightTrack.width));
                                root.setBrightness(Math.round(ratio * 100));
                            }
                            onPressed: (mouse) => setVal(mouse)
                            onPositionChanged: (mouse) => {
                                if (pressed) setVal(mouse);
                            }
                        }
                    }
                }
            }

            // ==========================================
            // VOLUME SLIDER
            // ==========================================
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Text {
                            text: root.sinkMuted ? "󰝟" : (root.sinkPercent > 60 ? "󰕾" : (root.sinkPercent > 25 ? "󰖀" : "󰕿"))
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            renderType: Theme.renderType
                            color: root.sinkMuted ? Theme.red : Theme.cyan
                            Layout.alignment: Qt.AlignVCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSinkMute()
                            }
                        }

                        Text {
                            text: "Volume"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            font.weight: Font.DemiBold
                            font.letterSpacing: Theme.trackingNormal
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.sinkMuted ? "MUTE" : (root.sinkPercent + "%")
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: root.sinkMuted ? Theme.red : Theme.cyan
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    // Track & Grab Handle + Arrow placed right beside the sound slider
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6

                        Rectangle {
                            id: volTrack
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 12
                            color: Theme.bgBase
                            border.color: Theme.borderDim
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Rectangle {
                                id: volFill
                                height: parent.height
                                width: root.sinkMuted ? 0 : Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, root.sinkVolume)))
                                color: root.sinkMuted ? Theme.textMuted : Theme.cyan
                                radius: Theme.squareRadius
                            }

                            Rectangle {
                                id: volThumb
                                width: 10
                                height: 18
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.max(0, Math.min(parent.width - width, volFill.width - (width / 2)))
                                color: volMouse.containsMouse || volMouse.pressed ? Theme.cyan : Theme.textPrimary
                                border.color: Theme.bgBase
                                border.width: 1
                                radius: Theme.squareRadius
                                visible: !root.sinkMuted
                            }

                            MouseArea {
                                id: volMouse
                                anchors.fill: parent
                                anchors.topMargin: -8
                                anchors.bottomMargin: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                function setVol(mouse) {
                                    if (!root.hasSink) return;
                                    let ratio = Math.max(0.0, Math.min(1.0, mouse.x / volTrack.width));
                                    root.sink.audio.volume = ratio;
                                    if (root.sink.audio.muted) root.sink.audio.muted = false;
                                }
                                onPressed: (mouse) => setVol(mouse)
                                onPositionChanged: (mouse) => {
                                    if (pressed) setVol(mouse);
                                }
                            }
                        }

                        // Arrow button placed right beside the sound slider
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 18
                            implicitHeight: 18
                            color: soundArrowMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            border.color: soundArrowMouse.containsMouse ? Theme.cyan : Theme.borderDim
                            border.width: 1
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                renderType: Theme.renderType
                                color: soundArrowMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                            }

                            MouseArea {
                                id: soundArrowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentView = "sound"
                            }
                        }
                    }
                }
            }

            // ==========================================
            // MEDIA CONTROLLER CARD (Visible when active)
            // ==========================================
            Rectangle {
                visible: root.activePlayer !== null
                Layout.fillWidth: true
                implicitHeight: 46
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        text: "󰎆"
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        renderType: Theme.renderType
                        color: root.isMediaPlaying ? Theme.cyan : Theme.textMuted
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: (root.activePlayer && root.activePlayer.trackTitle) ? root.activePlayer.trackTitle : "No Media"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadline
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (root.activePlayer && root.activePlayer.trackArtist) ? root.activePlayer.trackArtist : "Unknown Artist"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Transport controls
                    RowLayout {
                        spacing: 3

                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            color: pPrev.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            radius: Theme.squareRadius
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                renderType: Theme.renderType
                                color: pPrev.containsMouse ? Theme.cyan : Theme.textSecondary
                            }
                            MouseArea {
                                id: pPrev
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous();
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            color: pPlay.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            radius: Theme.squareRadius
                            Text {
                                anchors.centerIn: parent
                                text: root.isMediaPlaying ? "󰏤" : "󰐊"
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                renderType: Theme.renderType
                                color: root.isMediaPlaying ? Theme.cyan : Theme.textPrimary
                            }
                            MouseArea {
                                id: pPlay
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer) root.activePlayer.togglePlaying();
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            color: pNext.containsMouse ? Theme.bgSurfaceHover : "transparent"
                            radius: Theme.squareRadius
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                renderType: Theme.renderType
                                color: pNext.containsMouse ? Theme.cyan : Theme.textSecondary
                            }
                            MouseArea {
                                id: pNext
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next();
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // FOOTER: System Actions (Lock, Sleep, Logout, Reboot, Power)
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                // Lock Session
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 30
                    clip: true
                    color: lockMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: lockMouse.containsMouse ? Theme.borderBright : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰌾"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: Theme.blue
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Lock"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: lockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["hyprctl", "dispatch", "global", "quickshell:lock"]);
                        }
                    }
                }

                // Suspend / Sleep
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 30
                    clip: true
                    color: suspMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: suspMouse.containsMouse ? Theme.borderBright : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰤄"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: Theme.purple
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Sleep"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: suspMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["systemctl", "suspend"]);
                        }
                    }
                }

                // Logout
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 30
                    clip: true
                    color: logoutMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: logoutMouse.containsMouse ? Theme.borderBright : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰍃"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: Theme.cyan
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Logout"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: logoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["sh", "-c", "hyprctl dispatch 'hl.dsp.exit()' 2>/dev/null || loginctl terminate-session self || loginctl terminate-user \"$USER\""]);
                        }
                    }
                }

                // Reboot
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 30
                    clip: true
                    color: rebMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: rebMouse.containsMouse ? Theme.borderBright : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰑐"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: Theme.yellow
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Reboot"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: rebMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["systemctl", "reboot"]);
                        }
                    }
                }

                // Power Off
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 30
                    clip: true
                    color: pwrMouse.containsMouse ? Theme.red : Theme.bgSurface
                    border.color: pwrMouse.containsMouse ? Theme.red : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "󰐥"
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            renderType: Theme.renderType
                            color: pwrMouse.containsMouse ? Theme.textDark : Theme.red
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Power"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0
                            renderType: Theme.renderType
                            color: pwrMouse.containsMouse ? Theme.textDark : Theme.red
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: pwrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Theme.closePopup();
                            root.runCmd(["systemctl", "poweroff"]);
                        }
                    }
                }
            }
        }

        // ==========================================
        // INTEGRATED SOUND POPUP VIEW
        // ==========================================
        ColumnLayout {
            id: soundViewCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12
            enabled: root.currentView === "sound"
            visible: opacity > 0.001
            opacity: root.currentView === "sound" ? 1.0 : 0.0

            transform: Translate {
                x: root.currentView === "sound" ? 0 : 20
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            // Top Navigation Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 22
                    color: backMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: backMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "󰅁"; font.family: Theme.fontFamily; font.pixelSize: 10; renderType: Theme.renderType; color: Theme.cyan }
                        Text { text: "Back"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingNormal; renderType: Theme.renderType; color: Theme.textPrimary }
                    }

                    MouseArea {
                        id: backMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentView = "main"
                    }
                }

                Text {
                    text: "AUDIO & SOUND"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Master Mute Badge
                Rectangle {
                    implicitWidth: 52
                    implicitHeight: 22
                    color: root.sinkMuted ? Theme.red : (soundSinkMuteMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                    border.color: root.sinkMuted ? Theme.red : (soundSinkMuteMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: root.sinkMuted ? "MUTED" : "MUTE"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        renderType: Theme.renderType
                        color: root.sinkMuted ? Theme.textDark : (soundSinkMuteMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary)
                    }

                    MouseArea {
                        id: soundSinkMuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleSinkMute()
                    }
                }
            }

            // Output Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: root.sinkMuted ? "󰝟" : "󰕾"; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Theme.renderType; color: root.sinkMuted ? Theme.red : Theme.cyan }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "OUTPUT DEVICE"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingLoose; renderType: Theme.renderType; color: Theme.textPrimary }
                            Text { text: root.hasSink ? (root.sink.description || root.sink.name || "Default Output") : "No output sink"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead; font.weight: Font.Medium; font.letterSpacing: Theme.trackingTight; renderType: Theme.renderType; color: Theme.textMuted; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Text { text: root.sinkMuted ? "0%" : (root.sinkPercent + "%"); font.family: Theme.fontMono; font.pixelSize: Theme.fontHeadline; font.weight: Font.Bold; renderType: Theme.renderType; color: root.sinkMuted ? Theme.red : Theme.cyan }
                    }

                    // Output Slider Track
                    Rectangle {
                        id: sOutTrack
                        Layout.fillWidth: true
                        implicitHeight: 12
                        color: Theme.bgBase
                        border.color: Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Rectangle {
                            height: parent.height
                            width: root.sinkMuted ? 0 : Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, root.sinkVolume)))
                            color: root.sinkMuted ? Theme.textMuted : Theme.cyan
                            radius: Theme.squareRadius
                        }

                        Rectangle {
                            width: 10
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (root.sinkMuted ? 0 : parent.width * Math.min(1.0, root.sinkVolume)) - (width / 2)))
                            color: sOutMouse.containsMouse || sOutMouse.pressed ? Theme.cyan : Theme.textPrimary
                            border.color: Theme.bgBase
                            border.width: 1
                            radius: Theme.squareRadius
                            visible: !root.sinkMuted
                        }

                        MouseArea {
                            id: sOutMouse
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function setVol(mouse) {
                                if (!root.hasSink) return;
                                let ratio = Math.max(0.0, Math.min(1.0, mouse.x / sOutTrack.width));
                                root.sink.audio.volume = ratio;
                                if (root.sink.audio.muted) root.sink.audio.muted = false;
                            }
                            onPressed: (mouse) => setVol(mouse)
                            onPositionChanged: (mouse) => { if (pressed) setVol(mouse); }
                        }
                    }
                }
            }

            // Microphone / Input Section (if available)
            Rectangle {
                visible: root.hasSource
                Layout.fillWidth: true
                implicitHeight: 72
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text { text: root.sourceMuted ? "󰍭" : "󰍬"; font.family: Theme.fontFamily; font.pixelSize: 14; renderType: Theme.renderType; color: root.sourceMuted ? Theme.red : Theme.purple }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text { text: "INPUT MICROPHONE"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingLoose; renderType: Theme.renderType; color: Theme.textPrimary }
                            Text { text: root.hasSource ? (root.source.description || root.source.name || "Default Input") : "No input"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead; font.weight: Font.Medium; font.letterSpacing: Theme.trackingTight; renderType: Theme.renderType; color: Theme.textMuted; elide: Text.ElideRight; Layout.fillWidth: true }
                        }
                        Text { text: root.sourceMuted ? "0%" : (root.sourcePercent + "%"); font.family: Theme.fontMono; font.pixelSize: Theme.fontHeadline; font.weight: Font.Bold; renderType: Theme.renderType; color: root.sourceMuted ? Theme.red : Theme.purple }

                        // Mic Mute Button
                        Rectangle {
                            implicitWidth: 48
                            implicitHeight: 22
                            color: root.sourceMuted ? Theme.red : (sSrcMuteMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                            border.color: root.sourceMuted ? Theme.red : Theme.borderNormal
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Text {
                                anchors.centerIn: parent
                                text: root.sourceMuted ? "MUTED" : "MUTE"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.trackingLoose
                                renderType: Theme.renderType
                                color: root.sourceMuted ? Theme.textDark : Theme.textSecondary
                            }

                            MouseArea {
                                id: sSrcMuteMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleSourceMute()
                            }
                        }
                    }

                    // Mic Slider Track
                    Rectangle {
                        id: sInTrack
                        Layout.fillWidth: true
                        implicitHeight: 12
                        color: Theme.bgBase
                        border.color: Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Rectangle {
                            height: parent.height
                            width: root.sourceMuted ? 0 : Math.max(0, Math.min(parent.width, parent.width * Math.min(1.0, root.sourceVolume)))
                            color: root.sourceMuted ? Theme.textMuted : Theme.purple
                            radius: Theme.squareRadius
                        }

                        Rectangle {
                            width: 10
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, (root.sourceMuted ? 0 : parent.width * Math.min(1.0, root.sourceVolume)) - (width / 2)))
                            color: sInMouse.containsMouse || sInMouse.pressed ? Theme.purple : Theme.textPrimary
                            border.color: Theme.bgBase
                            border.width: 1
                            radius: Theme.squareRadius
                            visible: !root.sourceMuted
                        }

                        MouseArea {
                            id: sInMouse
                            anchors.fill: parent
                            anchors.topMargin: -8
                            anchors.bottomMargin: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function setVol(mouse) {
                                if (!root.hasSource) return;
                                let ratio = Math.max(0.0, Math.min(1.0, mouse.x / sInTrack.width));
                                root.source.audio.volume = ratio;
                                if (root.source.audio.muted) root.source.audio.muted = false;
                            }
                            onPressed: (mouse) => setVol(mouse)
                            onPositionChanged: (mouse) => { if (pressed) setVol(mouse); }
                        }
                    }
                }
            }
        }

        // ==========================================
        // INTEGRATED BATTERY POPUP VIEW
        // ==========================================
        ColumnLayout {
            id: batteryViewCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12
            enabled: root.currentView === "battery"
            visible: opacity > 0.001
            opacity: root.currentView === "battery" ? 1.0 : 0.0

            transform: Translate {
                x: root.currentView === "battery" ? 0 : 20
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            // Top Navigation Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 22
                    color: batBackMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: batBackMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "󰅁"; font.family: Theme.fontFamily; font.pixelSize: 10; renderType: Theme.renderType; color: Theme.cyan }
                        Text { text: "Back"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingNormal; renderType: Theme.renderType; color: Theme.textPrimary }
                    }

                    MouseArea {
                        id: batBackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentView = "main"
                    }
                }

                Text {
                    text: "BATTERY & POWER"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Status Badge
                Rectangle {
                    implicitWidth: batBadgeTxt.implicitWidth + 10
                    implicitHeight: 22
                    color: Theme.bgSurface
                    border.color: root.stateColor
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        id: batBadgeTxt
                        anchors.centerIn: parent
                        text: root.stateText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        renderType: Theme.renderType
                        color: root.stateColor
                    }
                }
            }

            // Battery Level Meter & Status Card
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
                            font.family: Theme.fontMono
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            renderType: Theme.renderType
                            color: root.stateColor
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: {
                                if (root.isCharging && root.uDev && root.uDev.timeToFull > 0) {
                                    return root.formatTime(root.uDev.timeToFull) + (root.changeRate > 0.05 ? (" (" + root.changeRate.toFixed(1) + " W)") : "");
                                }
                                if (root.isPluggedIn) {
                                    if (root.isFull || root.batteryPercent >= (root.chargeLimit > 0 ? root.chargeLimit - 1 : 98)) {
                                        return "0.0 W • AC Bypass";
                                    }
                                    return "0.0 W • On AC Power";
                                }
                                if (root.uDev && root.uDev.timeToEmpty > 0) {
                                    return root.formatTime(root.uDev.timeToEmpty) + (root.changeRate > 0.05 ? (" (" + root.changeRate.toFixed(1) + " W)") : "");
                                }
                                return root.changeRate > 0.05 ? (root.changeRate.toFixed(1) + " W") : "";
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textSecondary
                        }
                    }

                    // Progress Track
                    Rectangle {
                        id: batMeterTrack
                        Layout.fillWidth: true
                        implicitHeight: 10
                        color: Theme.bgBase
                        border.color: Theme.borderDim
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * (root.batteryPercent / 100.0)))
                            color: root.stateColor
                            radius: Theme.squareRadius
                        }

                        // Charge Limit Indicator Marker Line
                        Rectangle {
                            visible: root.chargeLimit > 0 && root.chargeLimit < 100
                            x: Math.round(parent.width * (root.chargeLimit / 100.0)) - 1
                            width: 2
                            height: parent.height + 4
                            y: -2
                            color: Theme.cyan
                            z: 2
                        }
                    }
                }
            }

            // Charge Limit Status Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
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
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        renderType: Theme.renderType
                        color: Theme.cyan
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: "CHARGE LIMIT"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingLoose
                            renderType: Theme.renderType
                            color: Theme.textPrimary
                        }

                        Text {
                            text: root.chargeLimit > 0 ? (root.chargeLimit + "% threshold active") : "No limit active"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textMuted
                        }
                    }

                    Rectangle {
                        implicitWidth: limitBadgeTxt.implicitWidth + 10
                        implicitHeight: 22
                        color: Theme.bgBase
                        border.color: Theme.cyan
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Text {
                            id: limitBadgeTxt
                            anchors.centerIn: parent
                            text: root.chargeLimit > 0 ? (root.chargeLimit + "% LIMIT") : "NO LIMIT"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            font.letterSpacing: Theme.trackingNormal
                            renderType: Theme.renderType
                            color: Theme.cyan
                        }
                    }
                }
            }

            // ASUS Power Profile Selector Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 68
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Text {
                        text: "POWER PROFILE (asusctl)"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        renderType: Theme.renderType
                        color: Theme.textSecondary
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                { name: "Quiet", icon: "󰈐" },
                                { name: "Balanced", icon: "󰓅" },
                                { name: "Performance", icon: "󰓦" }
                            ]

                            Rectangle {
                                id: profBtn
                                Layout.fillWidth: true
                                implicitHeight: 28
                                readonly property bool isActive: root.activeAsusProfile.toLowerCase() === modelData.name.toLowerCase()
                                color: isActive ? Theme.bgSurfaceActive : (profMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgBase)
                                border.color: isActive ? Theme.cyan : (profMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                                border.width: Theme.borderWidth
                                radius: Theme.squareRadius

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                        renderType: Theme.renderType
                                        color: profBtn.isActive ? Theme.cyan : Theme.textSecondary
                                    }
                                    Text {
                                        text: modelData.name
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSubhead
                                        font.weight: profBtn.isActive ? Font.Bold : Font.DemiBold
                                        font.letterSpacing: Theme.trackingTight
                                        renderType: Theme.renderType
                                        color: profBtn.isActive ? Theme.textPrimary : Theme.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: profMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setAsusProfile(modelData.name)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // INTEGRATED WI-FI POPUP VIEW
        // ==========================================
        ColumnLayout {
            id: wifiViewCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12
            enabled: root.currentView === "wifi"
            visible: opacity > 0.001
            opacity: root.currentView === "wifi" ? 1.0 : 0.0

            transform: Translate {
                x: root.currentView === "wifi" ? 0 : 20
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            // Top Navigation Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Back Button
                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 22
                    color: wifiBackMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: wifiBackMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "󰅁"; font.family: Theme.fontFamily; font.pixelSize: 10; renderType: Theme.renderType; color: Theme.cyan }
                        Text { text: "Back"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingNormal; renderType: Theme.renderType; color: Theme.textPrimary }
                    }

                    MouseArea {
                        id: wifiBackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentView = "main";
                        }
                    }
                }

                Text {
                    text: "WI-FI NETWORKS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Rescan Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 22
                    color: rescanMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: rescanMouse.containsMouse ? Theme.cyan : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        renderType: Theme.renderType
                        color: rescanMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.wifiDev) {
                                root.wifiDev.scannerEnabled = false;
                                root.wifiDev.scannerEnabled = true;
                            }
                        }
                    }
                }

                // Master Wi-Fi Switch
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 18
                    color: root.isWifiEnabled ? Theme.cyan : Theme.bgBase
                    border.color: root.isWifiEnabled ? Theme.cyan : Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isWifiEnabled ? (parent.width - width - 3) : 3
                        color: root.isWifiEnabled ? Theme.textDark : Theme.textMuted
                        radius: Theme.squareRadius

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.borderDim
            }

            // Wi-Fi Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // When disabled
                Rectangle {
                    visible: !root.isWifiEnabled
                    Layout.fillWidth: true
                    implicitHeight: 60
                    color: Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Wi-Fi is turned off"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 80
                            implicitHeight: 22
                            radius: Theme.squareRadius
                            color: Theme.bgSurfaceHover
                            border.color: Theme.cyan
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Turn On"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.trackingNormal
                                renderType: Theme.renderType
                                color: Theme.cyan
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Networking.wifiEnabled = true
                            }
                        }
                    }
                }

                // Networks List
                ColumnLayout {
                    visible: root.isWifiEnabled
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "AVAILABLE NETWORKS"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        renderType: Theme.renderType
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: {
                            if (!root.wifiDev || !root.wifiDev.networks) return [];
                            let nets = [];
                            for (let i = 0; i < root.wifiDev.networks.values.length; i++) {
                                let n = root.wifiDev.networks.values[i];
                                if (n && n.name && n.name.length > 0) {
                                    nets.push(n);
                                }
                            }
                            // Sort: connected first, then signal strength
                            nets.sort((a, b) => {
                                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                                return (b.signalStrength || 0) - (a.signalStrength || 0);
                            });
                            return nets.slice(0, 7);
                        }

                        Rectangle {
                            id: netItem
                            required property var modelData
                            readonly property var net: modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            color: net.connected ? Theme.bgSurfaceActive : (netMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                            border.color: net.connected ? Theme.cyan : (netMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Signal Icon
                                Text {
                                    text: {
                                        let s = netItem.net.signalStrength || 0;
                                        if (s >= 0.75) return "󰤨";
                                        if (s >= 0.50) return "󰤥";
                                        if (s >= 0.25) return "󰤢";
                                        return "󰤟";
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    renderType: Theme.renderType
                                    color: netItem.net.connected ? Theme.cyan : Theme.textSecondary
                                }

                                // SSID
                                Text {
                                    text: netItem.net.name || "Hidden Network"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    font.weight: netItem.net.connected ? Font.Bold : Font.DemiBold
                                    font.letterSpacing: Theme.trackingTight
                                    renderType: Theme.renderType
                                    color: netItem.net.connected ? Theme.cyan : Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Security Lock
                                Text {
                                    visible: netItem.net.security && netItem.net.security !== "" && netItem.net.security !== "none"
                                    text: "󰌾"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    renderType: Theme.renderType
                                    color: Theme.textMuted
                                }

                                // Status Badge / Action
                                Rectangle {
                                    implicitWidth: netItem.net.connected ? 70 : 54
                                    implicitHeight: 20
                                    color: netItem.net.connected ? "#1e2c34" : (actMouse.containsMouse ? Theme.bgSurfaceActive : Theme.bgBase)
                                    border.color: netItem.net.connected ? Theme.cyan : Theme.borderNormal
                                    border.width: 1
                                    radius: Theme.squareRadius

                                    Text {
                                        anchors.centerIn: parent
                                        text: netItem.net.connected ? "Disconnect" : "Connect"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.Bold
                                        font.letterSpacing: Theme.trackingNormal
                                        renderType: Theme.renderType
                                        color: netItem.net.connected ? Theme.cyan : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (netItem.net.connected) {
                                                netItem.net.disconnect();
                                            } else {
                                                netItem.net.connect();
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: netMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                z: -1
                                onClicked: {
                                    if (netItem.net.connected) {
                                        netItem.net.disconnect();
                                    } else {
                                        netItem.net.connect();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // INTEGRATED BLUETOOTH POPUP VIEW
        // ==========================================
        ColumnLayout {
            id: bluetoothViewCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12
            enabled: root.currentView === "bluetooth"
            visible: opacity > 0.001
            opacity: root.currentView === "bluetooth" ? 1.0 : 0.0

            transform: Translate {
                x: root.currentView === "bluetooth" ? 0 : 20
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            // Top Navigation Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Back Button
                Rectangle {
                    implicitWidth: 54
                    implicitHeight: 22
                    color: btBackMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: btBackMouse.containsMouse ? Theme.blue : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text { text: "󰅁"; font.family: Theme.fontFamily; font.pixelSize: 10; renderType: Theme.renderType; color: Theme.blue }
                        Text { text: "Back"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.Bold; font.letterSpacing: Theme.trackingNormal; renderType: Theme.renderType; color: Theme.textPrimary }
                    }

                    MouseArea {
                        id: btBackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentView = "main";
                        }
                    }
                }

                Text {
                    text: "BLUETOOTH DEVICES"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    renderType: Theme.renderType
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Scan / Discovery Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 22
                    color: btScanMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: (root.btAdapter && root.btAdapter.discovering) ? Theme.blue : (btScanMouse.containsMouse ? Theme.blue : Theme.borderNormal)
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        renderType: Theme.renderType
                        color: (root.btAdapter && root.btAdapter.discovering) ? Theme.blue : (btScanMouse.containsMouse ? Theme.blue : Theme.textSecondary)

                        RotationAnimation on rotation {
                            running: root.btAdapter && root.btAdapter.discovering
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1200
                        }
                    }

                    MouseArea {
                        id: btScanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.btAdapter) {
                                root.btAdapter.discovering = !root.btAdapter.discovering;
                            }
                        }
                    }
                }

                // Master Bluetooth Switch
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 18
                    color: root.isBtEnabled ? Theme.blue : Theme.bgBase
                    border.color: root.isBtEnabled ? Theme.blue : Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        width: 12
                        height: 12
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isBtEnabled ? (parent.width - width - 3) : 3
                        color: root.isBtEnabled ? Theme.textDark : Theme.textMuted
                        radius: Theme.squareRadius

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.hasBt) {
                                root.btAdapter.enabled = !root.btAdapter.enabled;
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.borderDim
            }

            // Bluetooth Content
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                // When disabled
                Rectangle {
                    visible: !root.isBtEnabled
                    Layout.fillWidth: true
                    implicitHeight: 60
                    color: Theme.bgSurface
                    border.color: Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Bluetooth is turned off"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.letterSpacing: Theme.trackingTight
                            renderType: Theme.renderType
                            color: Theme.textMuted
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 80
                            implicitHeight: 22
                            radius: Theme.squareRadius
                            color: Theme.bgSurfaceHover
                            border.color: Theme.blue
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "Turn On"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                font.letterSpacing: Theme.trackingNormal
                                renderType: Theme.renderType
                                color: Theme.blue
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.hasBt) root.btAdapter.enabled = true;
                                }
                            }
                        }
                    }
                }

                // Device List
                ColumnLayout {
                    visible: root.isBtEnabled
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: "PAIRED & NEARBY DEVICES"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        font.letterSpacing: Theme.trackingLoose
                        renderType: Theme.renderType
                        color: Theme.textMuted
                    }

                    Repeater {
                        model: {
                            if (!root.isBtEnabled || !Bluetooth.devices) return [];
                            let list = [];
                            for (let i = 0; i < Bluetooth.devices.values.length; i++) {
                                let dev = Bluetooth.devices.values[i];
                                if (dev && (dev.name || dev.deviceName)) {
                                    list.push(dev);
                                }
                            }
                            // Sort: connected first, then paired
                            list.sort((a, b) => {
                                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                                if (a.paired !== b.paired) return a.paired ? -1 : 1;
                                return (a.name || "").localeCompare(b.name || "");
                            });
                            return list.slice(0, 7);
                        }

                        Rectangle {
                            id: btItem
                            required property var modelData
                            readonly property var dev: modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            color: dev.connected ? Theme.bgSurfaceActive : (btDevMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                            border.color: dev.connected ? Theme.blue : (btDevMouse.containsMouse ? Theme.borderBright : Theme.borderNormal)
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Device Type Icon
                                Text {
                                    text: {
                                        let icon = btItem.dev.icon || "";
                                        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone")) return "󰋋";
                                        if (icon.includes("phone")) return "󰏲";
                                        if (icon.includes("input") || icon.includes("mouse") || icon.includes("keyboard")) return "󰌌";
                                        if (icon.includes("gamepad")) return "󰊴";
                                        return btItem.dev.connected ? "󰂱" : "󰂯";
                                    }
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 13
                                    renderType: Theme.renderType
                                    color: btItem.dev.connected ? Theme.blue : Theme.textSecondary
                                }

                                // Device Name
                                Text {
                                    text: btItem.dev.name || btItem.dev.deviceName || "Unknown Device"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    font.weight: btItem.dev.connected ? Font.Bold : Font.DemiBold
                                    font.letterSpacing: Theme.trackingTight
                                    renderType: Theme.renderType
                                    color: btItem.dev.connected ? Theme.blue : Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Connect / Disconnect Action Button
                                Rectangle {
                                    implicitWidth: btItem.dev.connected ? 70 : 54
                                    implicitHeight: 20
                                    color: btItem.dev.connected ? "#1c2234" : (btActMouse.containsMouse ? Theme.bgSurfaceActive : Theme.bgBase)
                                    border.color: btItem.dev.connected ? Theme.blue : Theme.borderNormal
                                    border.width: 1
                                    radius: Theme.squareRadius

                                    Text {
                                        anchors.centerIn: parent
                                        text: btItem.dev.connected ? "Disconnect" : "Connect"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCaption
                                        font.weight: Font.Bold
                                        font.letterSpacing: Theme.trackingNormal
                                        renderType: Theme.renderType
                                        color: btItem.dev.connected ? Theme.blue : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: btActMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (btItem.dev.connected) {
                                                btItem.dev.disconnect();
                                            } else {
                                                btItem.dev.connect();
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: btDevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                z: -1
                                onClicked: {
                                    if (btItem.dev.connected) {
                                        btItem.dev.disconnect();
                                    } else {
                                        btItem.dev.connect();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

