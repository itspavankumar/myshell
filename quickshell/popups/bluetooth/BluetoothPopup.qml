import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import qs.share.menu
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

    implicitWidth: 280
    implicitHeight: menuColumn.implicitHeight + 8
    grabFocus: true

    anchor {
        item: bluetoothWidget
        edges: Edges.Bottom
        rect.y: 32
        rect.x: bluetoothWidget.width / 2 - root.width / 2
    }
    color: "transparent"

    property BluetoothAdapter defaultAdapter: Bluetooth.defaultAdapter

    Item {
        id: animContainer
        anchors.fill: parent
        transformOrigin: Item.Top
        
        scale: root.isOpen ? 1.0 : 0.8
        opacity: root.isOpen ? 1.0 : 0.0
        
        Behavior on scale { SpringAnimation { id: closeAnim; spring: 3; damping: 0.2 } }
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


    // ── menu contents ────────────────────────────────────────────────────────
    ColumnLayout {
        id: menuColumn
        anchors {
            top: dropdown.top
            left: dropdown.left
            right: dropdown.right
            topMargin: 4
            bottomMargin: 4
            leftMargin: 0
            rightMargin: 0
        }
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 10
            color: "transparent"
        }
        RowLayout {

            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 14

            MenuLabel {
                label: "Bluetooth"
                labelElement.font.weight: (defaultAdapter && defaultAdapter.enabled) ? Font.Bold : Font.Normal
                Layout.fillWidth: true
            }
            Rectangle {

                implicitWidth: 48
                implicitHeight: 28
                color: (defaultAdapter && defaultAdapter.enabled) ? "#1687ff" : "#afb0b5"
                radius: 16
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: (defaultAdapter && defaultAdapter.enabled) ? 22 : 2
                    implicitWidth: 24
                    implicitHeight: 24
                    color: v.textColor
                    radius: 12
                    Behavior on x {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (defaultAdapter) defaultAdapter.enabled = !defaultAdapter.enabled;
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 160
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            color: "transparent"
        }
        MenuDiv {}
        // ── no adapter placeholder ────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            visible: !defaultAdapter
            sourceComponent: Item {
                implicitHeight: 36
                Text {
                    anchors.centerIn: parent
                    text: "No Bluetooth adapter found"
                    color: v.textPlaceholder
                    font.pixelSize: 13
                }
            }
        }

        // ── paired devices ─────────────────────────────────────────────
        MenuLabel {
            label: "Paired"
            labelElement.font.weight: 600
            labelElement.color: v.textHeader
            visible: defaultAdapter && defaultAdapter.enabled
        }

        Repeater {
            model: defaultAdapter ? defaultAdapter.devices : null

            delegate: IconItem {
                required property var modelData
                readonly property BluetoothDevice device: modelData

                visible: device.paired

                label: device.name || device.deviceName || device.address
                iconName: device.icon || "bluetooth-symbolic"
                selected: device.connected

                onTriggered: {
                    if (device.connected) {
                        device.disconnect();
                    } else {
                        device.connect();
                    }
                }
            }
        }

        // ── available devices (unpaired, with a real name) ─────────────
        MenuLabel {
            label: "Available"
            labelElement.font.weight: 600
            labelElement.color: v.textHeader
            visible: {
                if (!defaultAdapter || !defaultAdapter.enabled)
                    return false;
                for (let i = 0; i < defaultAdapter.devices.count; i++) {
                    let d = defaultAdapter.devices.get(i);
                    if (!d.paired && d.deviceName && d.deviceName.length > 0)
                        return true;
                }
                return false;
            }
        }

        Repeater {
            model: defaultAdapter ? defaultAdapter.devices : null

            delegate: IconItem {
                required property var modelData
                readonly property BluetoothDevice device: modelData

                // Only show unpaired devices that report a proper name
                visible: !device.paired && (device.deviceName && device.deviceName.length > 0)

                label: device.name || device.deviceName
                iconName: device.icon || "bluetooth-symbolic"
                selected: false

                onTriggered: {
                    device.connect();
                }
            }
        }

        MenuDiv {}
        MenuItem {
            label: "Bluetooth Settings..."
            onTriggered: {
                preferences.running = true;
                root.visible = false;
            }
        }

        Item {
            Layout.preferredHeight: 8
        }
    }
    } // animContainer

    Process {
        id: preferences
        command: ["blueman-manager"]
        running: false
    }
}
