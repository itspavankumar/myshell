import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Hyprland
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
    readonly property bool shouldBeOpen: Theme.activePopup === "network"
    property bool popupVisible: false
    visible: popupVisible
    implicitWidth: 250
    implicitHeight: mainCard.implicitHeight

    HyprlandFocusGrab {
        id: focusGrab
        windows: root.barWindow ? [root, root.barWindow] : [root]
        active: root.passwordPromptOpen && root.visible
        onCleared: {
            root.passwordPromptOpen = false;
        }
    }

    onShouldBeOpenChanged: {
        if (shouldBeOpen) {
            closeAnim.stop();
            popupVisible = true;
            anchor.updateAnchor();
            openAnim.restart();
            if (root.wifiDev) {
                root.wifiDev.scannerEnabled = true;
            }
            getSavedConnsProc.running = true;
            rescan();
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
        } else {
            popupVisible = false;
            passwordPromptOpen = false;
            connectError = "";
            if (Theme.activePopup === "network") {
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

    readonly property bool isWifiEnabled: Networking.wifiEnabled

    readonly property var wifiDev: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            let dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }

    onWifiDevChanged: {
        if (wifiDev) {
            wifiDev.scannerEnabled = true;
        }
    }

    readonly property var wiredDev: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            let dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wired) return dev;
        }
        return null;
    }

    readonly property bool isWiredConnected: wiredDev !== null && wiredDev.connected
    readonly property bool isWifiConnected: wifiDev !== null && wifiDev.connected

    function getSignalIcon(strength) {
        if (strength >= 0.8) return "󰤨";
        if (strength >= 0.6) return "󰤥";
        if (strength >= 0.4) return "󰤢";
        if (strength >= 0.2) return "󰤟";
        return "󰤯";
    }

    // ==========================================
    // RESCAN & CONNECTION PROCESSES
    // ==========================================
    property bool isScanning: false
    property var extraNetworks: []
    property var savedConnNames: ({})

    Timer {
        id: scanDurationTimer
        interval: 2200
        repeat: false
        onTriggered: root.isScanning = false
    }

    Process {
        id: getSavedConnsProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "con", "show"]
        stdout: SplitParser {
            onRead: (line) => {
                let parts = line.split(":");
                if (parts.length >= 2 && parts[1].includes("wireless")) {
                    root.savedConnNames[parts[0].trim()] = true;
                }
            }
        }
    }

    Process {
        id: rescanWifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "yes"]
        property var temp: []
        property var seen: ({})

        onRunningChanged: {
            if (running) {
                temp = [];
                seen = {};
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                line = line.trim();
                if (!line) return;
                let parts = line.split(":");
                if (parts.length >= 4) {
                    let inUse = parts[0].trim() === "*";
                    let ssid = parts[1].trim();
                    let sig = parseInt(parts[2].trim()) || 0;
                    let sec = parts[3].trim();
                    let isSecured = sec !== "" && sec !== "--";

                    if (ssid && !rescanWifiProc.seen[ssid]) {
                        rescanWifiProc.seen[ssid] = true;
                        rescanWifiProc.temp.push({
                            name: ssid,
                            signalStrength: sig / 100.0,
                            connected: inUse,
                            known: !!root.savedConnNames[ssid],
                            isSecured: isSecured
                        });
                    }
                }
            }
        }

        onExited: {
            root.extraNetworks = rescanWifiProc.temp;
        }
    }

    function rescan() {
        if (!isScanning) {
            isScanning = true;
            scanDurationTimer.restart();
            if (root.wifiDev) {
                root.wifiDev.scannerEnabled = true;
            }
            rescanWifiProc.running = true;
        }
    }

    property bool passwordPromptOpen: false
    property string selectedSsid: ""
    property bool showPassword: false
    property bool isConnecting: false
    property string connectError: ""

    onPasswordPromptOpenChanged: {
        if (passwordPromptOpen) {
            passInput.text = "";
            focusTimer.restart();
        } else {
            passInput.focus = false;
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        repeat: false
        onTriggered: {
            passInput.forceActiveFocus();
        }
    }

    Process {
        id: connectWifiProc
        onExited: (code) => {
            root.isConnecting = false;
            if (code === 0) {
                root.passwordPromptOpen = false;
                root.connectError = "";
                passInput.text = "";
                root.rescan();
            } else {
                if (root.connectError === "") {
                    root.connectError = "Check password.";
                }
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                if (line.includes("Secrets were required") || line.includes("property is invalid") || line.includes("failed")) {
                    root.connectError = "Invalid password.";
                }
            }
        }
    }

    function connectWithPassword() {
        if (!selectedSsid) return;
        isConnecting = true;
        connectError = "";
        let pass = passInput.text.trim();
        if (pass.length > 0) {
            connectWifiProc.command = ["nmcli", "dev", "wifi", "connect", selectedSsid, "password", pass];
        } else {
            connectWifiProc.command = ["nmcli", "dev", "wifi", "connect", selectedSsid];
        }
        connectWifiProc.running = true;
    }

    Process {
        id: genericWifiProc
    }

    function connectSavedNetwork(ssid) {
        genericWifiProc.command = ["nmcli", "dev", "wifi", "connect", ssid];
        genericWifiProc.running = true;
    }

    function disconnectNetwork(ssid) {
        genericWifiProc.command = ["nmcli", "con", "down", "id", ssid];
        genericWifiProc.running = true;
    }

    Rectangle {
        id: mainCard
        width: parent.width
        implicitHeight: contentCol.implicitHeight + 22
        color: Theme.bgGlass
        border.color: Theme.borderBright
        border.width: Theme.borderWidth
        radius: Theme.squareRadius
        opacity: 0.0

        transform: Scale {
            id: popupScale
            origin.x: mainCard.width / 2
            origin.y: 0
            xScale: 0.95
            yScale: 0.92
        }

        ColumnLayout {
            id: contentCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 8

            // ==========================================
            // HEADER: Title + Refresh + Master Wi-Fi Switch
            // ==========================================
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "󰤨"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    color: Theme.cyan
                }

                Text {
                    text: "WI-FI"
                    renderType: Theme.renderType
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Font.Bold
                    font.letterSpacing: Theme.trackingLoose
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Refresh Rescan Button
                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    color: root.isScanning ? Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.15) : (rescanMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface)
                    border.color: (root.isScanning || rescanMouse.containsMouse) ? Theme.cyan : Theme.borderNormal
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "󰑐"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: (root.isScanning || rescanMouse.containsMouse) ? Theme.cyan : Theme.textSecondary
                        transformOrigin: Item.Center

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RotationAnimation on rotation {
                            running: root.isScanning
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 750
                        }

                        Connections {
                            target: root
                            function onIsScanningChanged() {
                                if (!root.isScanning) {
                                    refreshIcon.rotation = 0;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rescanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rescan()
                    }
                }

                // Wi-Fi Sliding Switch Button
                Rectangle {
                    id: wifiSwitch
                    implicitWidth: 38
                    implicitHeight: 24
                    color: root.isWifiEnabled ? Theme.cyan : Theme.bgBase
                    border.color: root.isWifiEnabled ? Theme.cyan : Theme.borderDim
                    border.width: Theme.borderWidth
                    radius: Theme.squareRadius

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    // Sliding Thumb
                    Rectangle {
                        id: wifiThumb
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.isWifiEnabled ? (parent.width - width - 4) : 4
                        color: root.isWifiEnabled ? Theme.textDark : Theme.textMuted
                        radius: Theme.squareRadius

                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Networking.wifiEnabled = !Networking.wifiEnabled;
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

            // ==========================================
            // WIRED ETHERNET (If connected)
            // ==========================================
            Rectangle {
                visible: root.isWiredConnected
                Layout.fillWidth: true
                implicitHeight: 34
                color: Theme.bgSurface
                border.color: Theme.borderNormal
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰈀"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.green
                    }

                    Text {
                        text: "Ethernet"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "Connected"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        font.weight: Font.Bold
                        color: Theme.green
                    }
                }
            }

            // ==========================================
            // ACTIVE WI-FI (If connected)
            // ==========================================
            Rectangle {
                visible: root.isWifiConnected && root.isWifiEnabled
                Layout.fillWidth: true
                implicitHeight: 34
                color: Theme.bgSurface
                border.color: Theme.cyan
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    Text {
                        text: "󰤨"
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        color: Theme.cyan
                    }

                    Text {
                        text: {
                            if (root.wifiDev && root.wifiDev.networks.values.length > 0) {
                                for (let i = 0; i < root.wifiDev.networks.values.length; i++) {
                                    let net = root.wifiDev.networks.values[i];
                                    if (net && net.connected) return net.name || "Connected";
                                }
                            }
                            return "Connected";
                        }
                        renderType: Theme.renderType
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Disconnect Button
                    Rectangle {
                        implicitWidth: 64
                        implicitHeight: 22
                        color: disMouse.containsMouse ? Theme.red : Theme.bgSurfaceHover
                        border.color: Theme.red
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        Text {
                            anchors.centerIn: parent
                            text: "Disconnect"
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            font.weight: Font.Bold
                            color: disMouse.containsMouse ? Theme.textDark : Theme.red
                        }

                        MouseArea {
                            id: disMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.wifiDev && root.wifiDev.networks.values.length > 0) {
                                    for (let i = 0; i < root.wifiDev.networks.values.length; i++) {
                                        let net = root.wifiDev.networks.values[i];
                                        if (net && net.connected) {
                                            net.disconnect();
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // PASSWORD PROMPT CARD
            // ==========================================
            Rectangle {
                id: passCard
                visible: root.passwordPromptOpen
                Layout.fillWidth: true
                implicitHeight: passCol.implicitHeight + 14
                color: Theme.bgBase
                border.color: Theme.cyan
                border.width: Theme.borderWidth
                radius: Theme.squareRadius

                ColumnLayout {
                    id: passCol
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "󰌾 \"" + root.selectedSsid + "\""
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSubhead
                            font.weight: Font.DemiBold
                            color: Theme.cyan
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.connectError !== ""
                            text: root.connectError
                            renderType: Theme.renderType
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            color: Theme.red
                            elide: Text.ElideRight
                        }
                    }

                    // Password input field
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 28
                        color: Theme.bgSurface
                        border.color: passInput.activeFocus ? Theme.cyan : Theme.borderNormal
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: passInput
                                    anchors.fill: parent
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.textPrimary
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    activeFocusOnPress: true
                                    selectByMouse: true
                                    clip: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Password..."
                                        color: Theme.textMuted
                                        renderType: Theme.renderType
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontBody
                                        visible: !passInput.text && !passInput.activeFocus
                                    }

                                    onAccepted: root.connectWithPassword()

                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            root.connectWithPassword();
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            root.passwordPromptOpen = false;
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }

                            // Eye icon button
                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: root.showPassword ? "󰈈" : "󰈉"
                                    renderType: Theme.renderType
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    color: eyeMouse.containsMouse ? Theme.cyan : Theme.textSecondary
                                }

                                MouseArea {
                                    id: eyeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.showPassword = !root.showPassword;
                                        passInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    // Buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: 54
                            implicitHeight: 22
                            color: cancelMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                            border.color: Theme.borderNormal
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Text {
                                anchors.centerIn: parent
                                text: "Cancel"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.DemiBold
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.passwordPromptOpen = false;
                                    root.connectError = "";
                                    passInput.text = "";
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 64
                            implicitHeight: 22
                            color: root.isConnecting ? Theme.bgSurfaceActive : (connMouse.containsMouse ? Theme.cyan : Theme.bgSurface)
                            border.color: Theme.cyan
                            border.width: Theme.borderWidth
                            radius: Theme.squareRadius

                            Text {
                                anchors.centerIn: parent
                                text: root.isConnecting ? "..." : "Connect"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.weight: Font.Bold
                                color: (connMouse.containsMouse && !root.isConnecting) ? Theme.textDark : Theme.cyan
                            }

                            MouseArea {
                                id: connMouse
                                anchors.fill: parent
                                enabled: !root.isConnecting
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.connectWithPassword()
                            }
                        }
                    }
                }
            }

            // ==========================================
            // NETWORKS SECTION
            // ==========================================
            Text {
                text: "NETWORKS"
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.Bold
                font.letterSpacing: Theme.trackingLoose
                color: Theme.textMuted
                visible: root.isWifiEnabled
            }

            ColumnLayout {
                id: netCol
                spacing: 4
                Layout.fillWidth: true
                visible: root.isWifiEnabled

                Repeater {
                    model: {
                        if (!root.isWifiEnabled) return [];
                        let list = [];
                        let seen = {};

                        // 1. Quickshell native wifiDev.networks
                        if (root.wifiDev && root.wifiDev.networks) {
                            for (let i = 0; i < root.wifiDev.networks.values.length; i++) {
                                let n = root.wifiDev.networks.values[i];
                                if (n && n.name && n.name.length > 0 && !seen[n.name]) {
                                    seen[n.name] = true;
                                    list.push(n);
                                }
                            }
                        }

                        // 2. Extra networks discovered from nmcli scan
                        for (let j = 0; j < root.extraNetworks.length; j++) {
                            let en = root.extraNetworks[j];
                            if (en && en.name && en.name.length > 0 && !seen[en.name]) {
                                seen[en.name] = true;
                                list.push(en);
                            }
                        }

                        // 3. Sort: Connected first, then by signal strength descending
                        list.sort((a, b) => {
                            if (a.connected) return -1;
                            if (b.connected) return 1;
                            return (b.signalStrength || 0) - (a.signalStrength || 0);
                        });

                        return list.slice(0, 10);
                    }

                    Rectangle {
                        id: netItem
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        color: netMouse.containsMouse ? Theme.bgSurfaceHover : (modelData.connected ? Theme.bgSurfaceActive : Theme.bgSurface)
                        border.color: modelData.connected ? Theme.cyan : (netMouse.containsMouse ? Theme.borderBright : Theme.borderDim)
                        border.width: Theme.borderWidth
                        radius: Theme.squareRadius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: root.getSignalIcon(modelData.signalStrength)
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                color: modelData.connected ? Theme.cyan : Theme.textSecondary
                            }

                            Text {
                                text: modelData.name
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                font.letterSpacing: Theme.trackingTight
                                color: modelData.connected ? Theme.textPrimary : Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Lock indicator for password-protected unsaved networks
                            Text {
                                visible: !modelData.connected && !modelData.known
                                text: "󰌾"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                color: Theme.textMuted
                            }

                            Text {
                                visible: modelData.connected
                                text: "󰄬"
                                renderType: Theme.renderType
                                font.family: Theme.fontFamily
                                font.pixelSize: 11
                                color: Theme.green
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) {
                                    if (typeof modelData.disconnect === "function") {
                                        modelData.disconnect();
                                    } else {
                                        root.disconnectNetwork(modelData.name);
                                    }
                                } else if (modelData.known) {
                                    if (typeof modelData.connect === "function") {
                                        modelData.connect();
                                    } else {
                                        root.connectSavedNetwork(modelData.name);
                                    }
                                } else {
                                    root.selectedSsid = modelData.name;
                                    root.connectError = "";
                                    root.showPassword = false;
                                    passInput.text = "";
                                    root.passwordPromptOpen = true;
                                }
                            }
                        }
                    }
                }
            }

            // Placeholder if no networks found
            Text {
                visible: root.isWifiEnabled && (netCol.children.length <= 1)
                text: root.isScanning ? "Scanning for networks..." : "No networks found."
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }

            // Wi-Fi is disabled placeholder
            Text {
                visible: !root.isWifiEnabled
                text: "Wi-Fi is off."
                renderType: Theme.renderType
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubhead
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    Component.onCompleted: {
        getSavedConnsProc.running = true;
        if (wifiDev) {
            wifiDev.scannerEnabled = true;
        }
    }
}
