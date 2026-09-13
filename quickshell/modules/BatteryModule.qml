import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "../theme"
import "../popups"

Rectangle {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.isPresent
    
    // Calculate 0-100 percentage
    readonly property int batteryPercent: {
        if (!device) return 0;
        let p = device.percentage;
        return (p <= 1.0 && p > 0.0) ? Math.round(p * 100) : Math.round(p);
    }

    readonly property bool isPluggedIn: !UPower.onBattery

    readonly property bool isCharging: {
        if (!device) return false;
        return device.state === UPowerDeviceState.Charging;
    }

    readonly property bool isFull: {
        if (!device) return false;
        return device.state === UPowerDeviceState.FullyCharged || batteryPercent >= 98;
    }

    // Icon glyph
    readonly property string batteryIcon: {
        if (isCharging) return "󰂄";
        if (isPluggedIn) return "󰚥";
        if (batteryPercent >= 90) return "󰁹";
        if (batteryPercent >= 75) return "󰂁";
        if (batteryPercent >= 60) return "󰂀";
        if (batteryPercent >= 45) return "󰁿";
        if (batteryPercent >= 30) return "󰁾";
        if (batteryPercent >= 15) return "󰁽";
        return "󰁺";
    }

    // Dynamic accent color
    readonly property color stateColor: {
        if (isCharging) return Theme.cyan;
        if (isPluggedIn || isFull || batteryPercent >= 50) return Theme.green;
        if (batteryPercent >= 20) return Theme.yellow;
        return Theme.red;
    }

    implicitHeight: Theme.barHeight - 8
    implicitWidth: hasBattery ? (batteryRow.implicitWidth + 16) : 0
    visible: hasBattery

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "battery"
    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    property var barWindow: null

    BatteryPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
    }

    RowLayout {
        id: batteryRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.batteryIcon
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: root.stateColor
            renderType: Text.NativeRendering
        }

        Text {
            text: root.batteryPercent + "%"
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontBody
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackingTight
            color: Theme.textPrimary
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Theme.togglePopup("battery");
        }
    }
}
