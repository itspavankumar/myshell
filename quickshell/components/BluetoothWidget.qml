import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Widgets
import ".."
import qs.popups.bluetooth

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    implicitWidth: 32  // icon size + smaller pad
    Rectangle {
        id: bluetoothWidget
        anchors.fill: parent
        radius: 6
        color: bluetoothPopup.isOpen ? v.widgetHighlight : "transparent"
    }

    readonly property string iconSource: {
        if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled)
            return "../images/Bluetooth/bluetooth-disabled-symbolic.svg";
        return "../images/Bluetooth/bluetooth-active-symbolic.svg";
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bluetoothPopup.toggle();
        }
    }

    Image {
        anchors.centerIn: parent
        sourceSize.width: 18
        sourceSize.height: 18
        source: root.iconSource
    }
    BluetoothPopup {
        id: bluetoothPopup
    }
}
