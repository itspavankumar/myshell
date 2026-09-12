import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    Variables { id: v }
    id: root
    Layout.leftMargin: 6

    Layout.rightMargin: 3
    Layout.fillHeight: true
    implicitWidth: clockLabel.implicitWidth + 12

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
    }

    Text {
        id: clockLabel
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 6
        }
        text: Qt.formatDateTime(sysClock.date, "ddd MMM d   hh:mm AP")
        font.family: "SF Pro"
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: v.textColor
        renderType: Text.NativeRendering
    }

}
