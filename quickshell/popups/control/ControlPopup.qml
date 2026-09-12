import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Io
import "../.."

PopupWindow {
    Variables { id: v }
    id: root

    property bool isOpen: false

    Timer {
        id: closeTimer
        interval: 0
        onTriggered: {
            root.visible = false;
        }
    }

    function toggle() {
        if (isOpen) {
            isOpen = false;
            root.visible = false;
        } else {
            closeTimer.stop();
            isOpen = true;
            visible = true;
        }
    }

    onVisibleChanged: {
        if (!visible && isOpen) {
            isOpen = false;
        }
    }

    implicitWidth: 320
    implicitHeight: contentColumn.implicitHeight + 32
    grabFocus: true

    anchor {
        item: controlCenterWidget
        edges: Edges.Bottom
        rect.y: 32
        rect.x: controlCenterWidget.width / 2 - root.width / 2
    }
    color: "transparent"

    property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter

    property var wifiDev: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi) return d;
        }
        return null;
    }

    property var activeWifiNetwork: {
        if (!wifiDev) return null;
        let nets = wifiDev.networks.values;
        if (!nets) return null;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i];
        }
        return null;
    }

    property string activeWifiName: {
        if (!Networking.wifiEnabled) return "Off";
        if (activeWifiNetwork && activeWifiNetwork.name) return activeWifiNetwork.name;
        return "On";
    }

    property string activeBluetoothName: {
        if (!defaultAdapter || !defaultAdapter.enabled) return "Off";
        let devs = defaultAdapter.devices.values;
        if (!devs) return "On";
        let connectedNames = [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) connectedNames.push(devs[i].name || devs[i].deviceName);
        }
        if (connectedNames.length > 0) return connectedNames.join(", ");
        return "On";
    }

    Item {
        id: animContainer
        anchors.fill: parent
        transformOrigin: Item.TopRight
        x: root.isOpen ? 0 : 40
        scale: root.isOpen ? 1.0 : 0.95
        opacity: root.isOpen ? 1.0 : 0.0

        Behavior on x {
            SpringAnimation { id: closeAnim; spring: 3; damping: 0.2 }
        }
        Behavior on scale {
            SpringAnimation { id: scaleAnim; spring: 3; damping: 0.2 }
        }
        Behavior on opacity { NumberAnimation { id: opacityAnim; duration: 150 } }
    RectangularShadow {
        anchors.fill: dropdown
        anchors.margins: 2
        radius: Math.max(0, dropdown.radius - 2)
        blur: 10
        color: v.shadowColor
    }



    Rectangle {


        id: dropdown


        anchors.fill: parent


        anchors.margins: 8


        anchors.topMargin: 0


        radius: 16


        color: v.popupBackground


        border.color: v.popupBorder


        border.width: 1


    }


    ColumnLayout {
        id: contentColumn
        anchors {
            fill: dropdown
            margins: 12
        }
        spacing: 12

        // Top Split Section
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 124
            spacing: 14

            // Left Card: Wi-Fi & Bluetooth
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: v.barBackground
                border.color: v.barBorder

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Wi-Fi
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        
                        RowLayout {
                            id: wifiRow
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: Networking.wifiEnabled ? "#007aff" : v.widgetHighlight
                                Image {
                                    anchors.centerIn: parent
                                    sourceSize.width: 14
                                    sourceSize.height: 14
                                    source: Networking.wifiEnabled ? "/home/pavan/.config/quickshell/images/Network/network-wireless-symbolic.svg" : "/home/pavan/.config/quickshell/images/Network/network-wireless-offline-symbolic.svg"
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Text { 
                                    text: "Wi-Fi"
                                    color: v.textColor
                                    font.family: "SF Pro"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold 
                                }
                                Text { 
                                    text: root.activeWifiName
                                    color: v.textSecondary
                                    font.family: "SF Pro"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 60
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }

                    // Divider
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: v.barBorder }

                    // Bluetooth
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        
                        RowLayout {
                            id: btRow
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: defaultAdapter && defaultAdapter.enabled ? "#007aff" : v.widgetHighlight
                                Image {
                                    anchors.centerIn: parent
                                    sourceSize.width: 14
                                    sourceSize.height: 14
                                    source: defaultAdapter && defaultAdapter.enabled ? "/home/pavan/.config/quickshell/images/Bluetooth/bluetooth-active-symbolic.svg" : "/home/pavan/.config/quickshell/images/Bluetooth/bluetooth-disabled-symbolic.svg"
                                }
                            }
                            ColumnLayout {
                                spacing: 0
                                Text { 
                                    text: "Bluetooth"
                                    color: v.textColor
                                    font.family: "SF Pro"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold 
                                }
                                Text { 
                                    text: root.activeBluetoothName
                                    color: v.textSecondary
                                    font.family: "SF Pro"
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 60
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (defaultAdapter) defaultAdapter.enabled = !defaultAdapter.enabled;
                        }
                    }
                }
            }

            // Right Card: Focus
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: v.barBackground
                border.color: v.barBorder

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    Rectangle {
                        implicitWidth: 44
                        implicitHeight: 44
                        radius: 22
                        color: v.widgetHighlight
                        Layout.alignment: Qt.AlignHCenter
                        Image {
                            anchors.centerIn: parent
                            sourceSize.width: 22
                            sourceSize.height: 22
                            source: "/home/pavan/.config/quickshell/images/System/weather-clear-night-symbolic.svg"
                        }
                    }
                    Text { 
                        text: "DND"
                        color: v.textColor
                        font.family: "SF Pro"
                        font.pixelSize: 14
                        font.weight: Font.Bold 
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }

        // Display Slider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: 12
            color: v.barBackground
            border.color: v.barBorder
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text { 
                    text: "Display"
                    color: v.textColor
                    font.family: "SF Pro"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold 
                }
                
                Slider {
                    id: brightSlider
                    Layout.fillWidth: true
                    from: 0; to: 1
                    value: brightData.brightness
                    height: 28
                    background: Rectangle {
                        x: brightSlider.leftPadding
                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                        width: brightSlider.availableWidth
                        height: 28
                        radius: 14
                        color: "#30303030"
                        border.width: 1
                        border.color: v.widgetHighlight
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 14
                            color: "transparent"

                            Rectangle {
                                width: brightSlider.visualPosition * (parent.width - 24) + 12
                                height: parent.height
                                color: v.textColor
                            }
                            Image {
                                x: 6
                                y: 4
                                sourceSize.width: 18
                                sourceSize.height: 18
                                source: "../../images/Display/display-brightness-symbolic.svg"
                                opacity: 0.3
                                visible: true
                            }
                        }
                    }
                    handle: Rectangle {
                        x: brightSlider.leftPadding + (brightSlider.availableWidth - 28) * brightSlider.visualPosition
                        y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: v.textColor
                        border.color: v.popupBorder
                        border.width: 1
                    }
                    onMoved: {
                        var val = Math.max(5, Math.floor(brightSlider.visualPosition * 100));
                        brightnessSetter.command = ["bash", "-c", "brightnessctl s " + val + "%"]
                        brightnessSetter.running = true
                    }
                }
            }
        }

        // Sound Slider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            radius: 12
            color: v.barBackground
            border.color: v.barBorder
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 18

                    RowLayout {
                        id: soundHeader
                        anchors.fill: parent
                        spacing: 4
                        
                        Text { 
                            text: "Sound"
                            color: v.textColor
                            font.family: "SF Pro"
                            font.pixelSize: 13
                            font.weight: Font.DemiBold 
                        }
                        Item { Layout.fillWidth: true }
                        Image {
                            source: "/home/pavan/.config/quickshell/images/System/preferences-system-symbolic.svg"
                            sourceSize.width: 14
                            sourceSize.height: 14
                            opacity: 0.5
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            soundPrefs.running = true;
                            root.visible = false;
                        }
                    }
                }
                
                Slider {
                    id: volSlider
                    Layout.fillWidth: true
                    from: 0; to: 1
                    value: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio.volume : 0
                    height: 28
                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        width: volSlider.availableWidth
                        height: 28
                        radius: 14
                        color: "#30303030"
                        border.width: 1
                        border.color: v.widgetHighlight
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 14
                            color: "transparent"

                            Rectangle {
                                width: volSlider.visualPosition * (parent.width - 24) + 12
                                height: parent.height
                                color: v.textColor
                            }
                            Image {
                                x: 6
                                y: 4
                                sourceSize.width: 18
                                sourceSize.height: 18
                                source: "../../images/Audio/audio-volume-high-symbolic.svg"
                                opacity: 0.3
                                visible: true
                            }
                        }
                    }
                    handle: Rectangle {
                        x: volSlider.leftPadding + (volSlider.availableWidth - 28) * volSlider.visualPosition
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: v.textColor
                        border.color: v.popupBorder
                        border.width: 1
                    }
                    onMoved: {
                        Pipewire.defaultAudioSink.audio.volume = volSlider.visualPosition;
                    }
                }
            }
        }
        
        Item { Layout.fillHeight: true } // Spacer
    }
    } // animContainer

    property var brightData: {"brightness": 1.0}

    Process {
        id: brightProc
        command: ["bash", "-c", "while true; do max=$(brightnessctl m 2>/dev/null); current=$(brightnessctl g 2>/dev/null); if [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then percent=$(echo \"scale=2; $current / $max\" | bc); echo \"{\\\"brightness\\\":$percent}\"; else echo \"{\\\"brightness\\\":1.0}\"; fi; sleep 2; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data) {
                    try { root.brightData = JSON.parse(data); } catch(e) {}
                }
            }
        }
    }

    Process {
        id: brightnessSetter
        running: false
    }

    Process {
        id: soundPrefs
        command: ["pavucontrol"]
        running: false
    }

    Process {
        id: wifiPrefs
        command: ["nm-connection-editor"]
        running: false
    }

    Process {
        id: btPrefs
        command: ["blueman-manager"]
        running: false
    }
}
