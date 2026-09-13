import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"
import "../popups"

Rectangle {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    implicitHeight: Theme.barHeight - 8
    implicitWidth: clockRow.implicitWidth + 18

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "clock"
    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.purple : (mouseArea.containsMouse ? Theme.purple : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    property var barWindow: null

    ClockPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
    }

    RowLayout {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: "󰥔"
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.purple
            renderType: Text.NativeRendering
        }

        Text {
            text: Qt.formatDateTime(clock.date, "hh:mm")
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontHeadline
            font.weight: Font.DemiBold
            font.letterSpacing: 0.6
            color: Theme.textPrimary
            renderType: Text.NativeRendering
        }

        Rectangle {
            implicitWidth: 1
            implicitHeight: 12
            color: Theme.borderBright
        }

        Text {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
            font.letterSpacing: Theme.trackingTight
            color: Theme.textSecondary
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Theme.togglePopup("clock");
        }
    }
}
