import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Quickshell.Widgets
import ".."
import qs.popups.battery

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    implicitWidth: contentRow.implicitWidth + 16

    readonly property var battery: UPower.displayDevice

    readonly property bool charging: {
        let s = battery.state;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge;
    }
    Rectangle {
        id: batteryWidget
        anchors.fill: parent

        radius: 6
        color: batteryPopup.isOpen ? v.widgetHighlight : "transparent"
    }

    readonly property string iconName: {
        let pct = battery.ready ? Math.round(battery.percentage * 10) * 10 : 10;
        pct = Math.max(10, Math.min(100, pct));
        if (charging) {
            return "battery-charging-" + pct + ".svg";
        } else {
            return "battery" + pct + ".svg";
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            batteryPopup.toggle();
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: battery.ready ? Math.round(battery.percentage * 100) + "%" : "--%"
            color: v.textColor
            font.family: "SF Pro"
            font.pixelSize: 13
            font.weight: Font.ExtraBold
        }

        Image {
            id: batteryIcon
            sourceSize.width: 28
            sourceSize.height: 22
            source: "../images/Battery/" + root.iconName
        }
    }
    BatteryPopup {
        id: batteryPopup
    }
}
