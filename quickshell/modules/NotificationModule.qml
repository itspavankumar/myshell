import QtQuick
import QtQuick.Layouts
import "../theme"
import "../popups"

Rectangle {
    id: root

    property var barWindow: null
    property var service: null

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "notifications"
    readonly property bool isDnd: service && service.dnd
    readonly property int unread: service ? service.unreadCount : 0

    implicitHeight: Theme.moduleHeight
    implicitWidth: notifRow.implicitWidth + 14

    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    NotificationCenterPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
        service: root.service
    }

    RowLayout {
        id: notifRow
        anchors.centerIn: parent
        spacing: 5

        // Bell Icon
        Text {
            text: root.isDnd ? "󰂛" : (root.unread > 0 ? "󰂞" : "󰂚")
            font.family: Theme.fontFamily
            font.pixelSize: 12
            color: root.isDnd ? Theme.yellow : (root.unread > 0 || root.isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.textPrimary : Theme.textSecondary))
            renderType: Text.NativeRendering
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Unread Count Badge
        Text {
            visible: root.unread > 0
            text: root.unread.toString()
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSubhead
            font.weight: Font.Bold
            font.letterSpacing: Theme.trackingTight
            color: Theme.cyan
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Theme.togglePopup("notifications");
        }
    }
}
