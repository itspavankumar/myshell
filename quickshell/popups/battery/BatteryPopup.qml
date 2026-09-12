import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower

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

    function formatBatteryTime(seconds) {
        if (seconds <= 0) return "Estimating...";
        var hrs = Math.floor(seconds / 3600);
        var mins = Math.floor((seconds % 3600) / 60);
        if (hrs > 0) return hrs + "h " + mins + "m";
        return mins + "m";
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

    implicitWidth: 300
    implicitHeight: menuColumn.implicitHeight + 8
    grabFocus: true
    readonly property var battery: UPower.displayDevice

    anchor {
        item: batteryWidget
        edges: Edges.Bottom
        rect.y: 32
        rect.x: batteryWidget.width / 2 - root.width / 2
    }
    color: "transparent"

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
        MenuLabel {
            label: "Battery"
            secondary: String(Math.round(battery.percentage * 100)) + "%"
            secondaryElement.color: v.textColor
            labelElement.font.weight: 600
        }
        MenuLabel {
            label: "Power Source:  " + (battery.state != 2 ? "Power Adapter" : "Battery")
            labelElement.color: v.textSecondary
        }
        MenuLabel {
            label: {
                var rateStr = String(Math.round(battery.changeRate * 10) / 10);
                if (battery.state === 1 || (battery.state !== 2 && battery.changeRate > 2)) {
                    return root.formatBatteryTime(battery.timeToFull) + " to full (" + rateStr + "W)";
                } else if (battery.state === 2) {
                    return root.formatBatteryTime(battery.timeToEmpty) + " left (" + rateStr + "W)";
                } else if (battery.state === 4 || battery.percentage === 1.0) {
                    return "Fully Charged";
                } else {
                    return "Plugged In";
                }
            }
            labelElement.color: v.textSecondary
        }

        MenuDiv {}

        MenuLabel {
            label: "Energy Mode"
            labelElement.font.weight: Font.Bold
            labelElement.color: v.textSecondary
        }

        IconItem {
            label: "Performance"
            selected: (root.asusProfile === "Performance")
            onTriggered: {
                asusSetter.command = ["bash", "-c", "asusctl profile set Performance"]
                asusSetter.running = true
                root.asusProfile = "Performance"
            }
            iconName: "battery-profile-performance"
        }
        IconItem {
            label: "Balanced"
            selected: (root.asusProfile === "Balanced")
            onTriggered: {
                asusSetter.command = ["bash", "-c", "asusctl profile set Balanced"]
                asusSetter.running = true
                root.asusProfile = "Balanced"
            }
            iconName: "battery-040"
        }
        IconItem {
            label: "Quiet"
            selected: (root.asusProfile === "Quiet")
            onTriggered: {
                asusSetter.command = ["bash", "-c", "asusctl profile set Quiet"]
                asusSetter.running = true
                root.asusProfile = "Quiet"
            }
            iconName: "battery-profile-powersave"
        }

        // bottom padding
        Item {
            Layout.preferredHeight: 8
        }
    }
    } // animContainer

    property string asusProfile: "Balanced"

    Process {
        id: asusProc
        command: ["bash", "-c", "while true; do asusctl profile get 2>/dev/null; sleep 2; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data && data.startsWith("Active profile:")) {
                    root.asusProfile = data.split(":")[1].trim();
                }
            }
        }
    }

    Process {
        id: asusSetter
        running: false
    }
}
