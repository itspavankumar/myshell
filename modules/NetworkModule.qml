import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../theme"
import "../popups"

Rectangle {
    id: root

    readonly property bool isWifiEnabled: Networking.wifiEnabled
    
    // Check connected devices
    readonly property var wifiDev: {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            let dev = Networking.devices.values[i];
            if (dev && dev.type === DeviceType.Wifi) return dev;
        }
        return null;
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

    readonly property string netIcon: {
        if (isWiredConnected) return "󰈀";
        if (!isWifiEnabled) return "󰤭";
        if (isWifiConnected) return "󰤨";
        return "󰤟";
    }

    readonly property string netText: {
        if (isWiredConnected) return "ETH";
        if (isWifiConnected && wifiDev && wifiDev.networks.values.length > 0) {
            // Find active network SSID if available
            for (let i = 0; i < wifiDev.networks.values.length; i++) {
                let net = wifiDev.networks.values[i];
                if (net && net.connected) return net.ssid || "WiFi";
            }
            return "WiFi";
        }
        if (!isWifiEnabled) return "OFF";
        return "DISC";
    }

    implicitHeight: Theme.barHeight - 8
    implicitWidth: netRow.implicitWidth + 16

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "network"
    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    property var barWindow: null

    NetworkPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
    }

    RowLayout {
        id: netRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.netIcon
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: (root.isWiredConnected || root.isWifiConnected) ? Theme.cyan : Theme.textMuted
            renderType: Text.NativeRendering
        }

        Text {
            text: root.netText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: (root.isWiredConnected || root.isWifiConnected) ? Theme.textPrimary : Theme.textMuted
            elide: Text.ElideRight
            Layout.maximumWidth: 100
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Networking.wifiEnabled = !Networking.wifiEnabled;
            } else {
                Theme.togglePopup("network");
            }
        }
    }
}
