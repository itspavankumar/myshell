import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import ".."
import qs.popups.control

Item {
    Variables { id: v }
    id: root

    Layout.fillHeight: true
    Layout.leftMargin: 4
    implicitWidth: 24

    Rectangle {
        id: controlCenterWidget
        anchors.fill: parent
        radius: 6
        color: controlPopup.isOpen ? v.widgetHighlight : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            controlPopup.toggle();
        }
    }
    Image {
        id: icon
        anchors.centerIn: parent
        sourceSize.width: 18
        sourceSize.height: 18
        source: "../images/System/preferences-system-symbolic.svg"
        visible: true
    }
    ControlPopup {
        id: controlPopup
    }
}
