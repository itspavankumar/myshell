import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."
import qs.popups.notification

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    Layout.leftMargin: 4
    implicitWidth: 24

    Rectangle {
        id: notifWidget
        anchors.fill: parent
        anchors.leftMargin: 0
        anchors.rightMargin: 3
        radius: 6
        color: notifPopup.visible ? v.widgetHighlight : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            notifPopup.visible = !notifPopup.visible;
        }
    }

    Image {
        anchors.centerIn: parent
        sourceSize.width: 14
        sourceSize.height: 14
        source: "../images/System/bell-outline-symbolic.svg"
    }
    
    NotificationPopup {
        id: notifPopup
    }
}
