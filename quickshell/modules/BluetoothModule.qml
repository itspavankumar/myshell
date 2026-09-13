import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import "../theme"
import "../popups"

Rectangle {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool isEnabled: hasAdapter && adapter.enabled
    readonly property int connectedCount: {
        if (!hasAdapter) return 0;
        let count = 0;
        for (let i = 0; i < Bluetooth.devices.values.length; i++) {
            let dev = Bluetooth.devices.values[i];
            if (dev && dev.connected) count++;
        }
        return count;
    }

    readonly property string connectedDeviceName: {
        if (!hasAdapter) return "";
        let devs = Bluetooth.devices.values;
        for (let i = 0; i < devs.length; i++) {
            let dev = devs[i];
            if (dev && dev.connected) {
                return dev.name || dev.deviceName || "Connected";
            }
        }
        return "";
    }

    readonly property string btIcon: {
        if (!isEnabled) return "󰂲";
        if (connectedCount > 0) return "󰂱";
        return "󰂯";
    }

    readonly property color iconColor: {
        if (!isEnabled) return Theme.textMuted;
        if (connectedCount > 0) return Theme.cyan;
        return Theme.blue;
    }

    implicitHeight: Theme.barHeight - 8
    implicitWidth: btRow.implicitWidth + 16
    visible: hasAdapter

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "bluetooth"
    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    property var barWindow: null

    BluetoothPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
    }

    RowLayout {
        id: btRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.btIcon
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: root.iconColor
            renderType: Text.NativeRendering
        }

        Text {
            visible: root.connectedCount > 0
            text: root.connectedDeviceName
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: Theme.textPrimary
            elide: Text.ElideRight
            Layout.maximumWidth: 110
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
                if (root.hasAdapter) {
                    root.adapter.enabled = !root.adapter.enabled;
                }
            } else {
                Theme.togglePopup("bluetooth");
            }
        }
    }
}
