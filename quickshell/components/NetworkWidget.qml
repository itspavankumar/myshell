import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Widgets
import ".."
import qs.popups.network

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    implicitWidth: 24
    Rectangle {
        id: networkWidget
        anchors.fill: parent
        radius: 6
        color: networkPopup.isOpen ? v.widgetHighlight : "transparent"
    }

    readonly property var wifiDevice: {
        let devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected && devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }

    readonly property var activeWifiNetwork: {
        if (!wifiDevice)
            return null;
        let nets = wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                return nets[i];
        }
        return null;
    }

    readonly property bool ethernetConnected: {
        let devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected && devs[i].type !== DeviceType.Wifi)
                return true;
        }
        return false;
    }

    readonly property string iconSource: {
        if (activeWifiNetwork) {
            let s = activeWifiNetwork.signalStrength;
            if (s > 0.75)
                return "../images/Network/network-wireless-signal-excellent-symbolic.svg";
            if (s > 0.50)
                return "../images/Network/network-wireless-signal-good-symbolic.svg";
            if (s > 0.25)
                return "../images/Network/network-wireless-signal-weak-symbolic.svg";
            return "../images/Network/network-wireless-signal-none-symbolic.svg";
        }
        if (ethernetConnected)
            return "image://icon/network-wired";
        return "../images/Network/network-wireless-offline-symbolic.svg";
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            networkPopup.toggle();
        }
    }

    Image {
        anchors.centerIn: parent
        sourceSize.width: 18
        sourceSize.height: 18
        source: root.iconSource
    }
    NetworkPopup {
        id: networkPopup
    }
}
