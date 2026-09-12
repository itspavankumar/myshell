import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Networking
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
        if (wifiDev) {
            wifiDev.scannerEnabled = visible;
        }
    }
    implicitWidth: 280
    implicitHeight: menuColumn.implicitHeight + 8
    grabFocus: true
    anchor {
        item: networkWidget
        edges: Edges.Bottom
        rect.y: 32
        rect.x: networkWidget.width / 2 - root.width / 2
    }
    color: "transparent"

    // ── networking ───────────────────────────────────────────────────────────
    // Networking is a singleton — access directly, do not instantiate.
    // Find the first WifiDevice from Networking.devices.
    property WifiDevice wifiDev: {
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }
    // Enable scanner while popup is visible so the list stays live.
    // Enable scanner while popup is visible so the list stays live.

    Item {
        id: animContainer
        anchors.fill: parent
        transformOrigin: Item.Top
        
        scale: root.isOpen ? 1.0 : 0.8
        opacity: root.isOpen ? 1.0 : 0.0
        
        Behavior on scale {
            SpringAnimation { id: closeAnim; spring: 3; damping: 0.2 }
        }
        Behavior on opacity {
            NumberAnimation { id: opacityAnim; duration: 150 }
        }
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
                label: "Wi-Fi"
                labelElement.font.weight: Networking.wifiEnabled ? Font.Bold : Font.Normal
                Layout.fillWidth: true
            }
            Rectangle {

                implicitWidth: 48
                implicitHeight: 28
                color: Networking.wifiEnabled ? "#1687ff" : "#afb0b5"
                radius: 16
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Networking.wifiEnabled ? 22 : 2
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
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
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
            implicitHeight: 3
            color: "transparent"
        }

        MenuDiv {}

        MenuLabel {
            label: "Networks"
            labelElement.font.weight: 600
            labelElement.color: v.textPlaceholder
        }

        // ── no adapter / scanning placeholder ────────────────────────────────
        Loader {
            Layout.fillWidth: true
            visible: !wifiDev || (wifiDev.networks.count === 0)
            sourceComponent: Item {
                implicitHeight: 36
                Text {
                    anchors.centerIn: parent
                    text: !wifiDev ? "No Wi-Fi adapter found" : wifiDev.scannerEnabled ? "Scanning…" : "No networks"
                    color: v.textPlaceholder
                    font.pixelSize: 13
                }
            }
        }

        // ── network list ─────────────────────────────────────────────────────
        // WifiDevice.networks is an ObjectModel; each item is a
        // connect(), disconnect(), forget()
        Repeater {
            model: wifiDev ? wifiDev.networks : null

            delegate: IconItem {
                required property WifiNetwork modelData

                label: modelData.name || "(hidden)"

                iconName: {
                    const secured = modelData.security !== WifiSecurityType.None;
                    const s = modelData.signalStrength;
                    if (s > 0.75)
                        return "network-wireless-signal-excellent-symbolic";
                    if (s > 0.50)
                        return "network-wireless-signal-good-symbolic";
                    if (s > 0.25)
                        return "network-wireless-signal-weak-symbolic";
                    return "network-wireless-signal-none-symbolic";
                }
                // Highlight the currently connected network
                selected: modelData.connected

                onTriggered: {
                    if (modelData.connected) {
                        // Already connected — disconnect on second click
                        modelData.disconnect();
                    } else {
                        // connect() fires; an NM auth agent handles passwords
                        // for unknown secured networks automatically
                        modelData.connect();
                    }
                    root.visible = false;
                }
            }
        }

        MenuDiv {}

        MenuItem {
            label: "Wi-Fi Settings…"
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

    // ── processes ────────────────────────────────────────────────────────────
    Process {
        id: preferences
        command: ["nm-connection-editor"]
        running: false
    }
}
