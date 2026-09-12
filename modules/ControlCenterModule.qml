import QtQuick
import QtQuick.Layouts
import "../theme"
import "../popups"

Rectangle {
    id: root

    implicitHeight: Theme.moduleHeight
    implicitWidth: 26

    property var barWindow: null

    readonly property bool isPopupOpen: popup.visible && Theme.activePopup === "controlcenter"
    color: (mouseArea.containsMouse || isPopupOpen) ? Theme.bgSurfaceHover : Theme.bgSurface
    border.color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.borderBright : Theme.borderNormal)
    border.width: Theme.borderWidth
    radius: Theme.squareRadius

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    ControlCenterPopup {
        id: popup
        targetItem: root
        barWindow: root.barWindow
    }

    Text {
        anchors.centerIn: parent
        text: "󰘳"
        renderType: Theme.renderType
        font.family: Theme.fontFamily
        font.pixelSize: 12
        color: isPopupOpen ? Theme.cyan : (mouseArea.containsMouse ? Theme.textPrimary : Theme.textSecondary)

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Theme.togglePopup("controlcenter");
        }
    }
}

